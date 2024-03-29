/*#D*/
// Copyright 2012, Bernard Helyer.
// Copyright 2012, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volt.visitor.prettyprinter;

import watt.conv : toString;
import watt.io.streams : OutputStream;
import watt.io.std : writefln, writef, output;
import watt.text.format : format;

import ir = volta.ir;
import volta.ir.printer;
import volta.ir.location;

import volt.errors;
import volt.interfaces;
import volta.ir.token;
import volta.visitor.visitor;


void prettyPrinter(ir.Module m)
{
	auto pp = new PrettyPrinter();
	pp.transform(m);
	pp.close();
}

class PrettyPrinter : Visitor, Pass
{
protected:
	string mFilename;
	OutputStream mStream;
	void delegate(scope const(char)[]) mSink;

	int mIndent;
	string mIndentText;
	int mPrintingTemplateDefinition;


public:
	this(string indentText = "\t", void delegate(scope const(char)[]) sink = null)
	{
		mIndentText = indentText;
		mSink = sink;
	}

	override void close()
	{
		mFilename = null;
		assert(mStream is null);
		assert(mFilename is null);
	}

	override Status visitingError(ir.Node n, string msg)
	{
		writefln("visiting error: %s", msg);
		return Stop;
	}

	/*
	 *
	 * Pass functions.
	 *
	 */


	override void transform(ir.Module m)
	in {
		assert(mStream is null);
		assert(mFilename is null);
	}
	do {
		assert(mStream is null);
		assert(mFilename is null);

		mStream = output;
		void sink(scope const(char)[] s)
		{
			mStream.writef("%s", s);
		}
		bool sinkWasNull;
		if (mSink is null) {
			mSink = sinkToStream;
			sinkWasNull = true;
		}

		accept(m, this);
		mSink("\n");
		mStream = null;
		if (sinkWasNull) {
			mSink = null;
		}
	}

	void transformType(ir.Type t)
	{
		accept(t, this);
	}


	/*
	 *
	 * Root
	 *
	 */

	override Status visit(ir.Identifier i)
	{
		wf(i.value);
		return Continue;
	}

	override Status visit(ir.QualifiedName qname)
	{
		if (qname.leadingDot) {
			wf(".");
		}
		foreach (i, ident; qname.identifiers) {
			accept(ident, this);
			if (i < qname.identifiers.length - 1) {
				wf(".");
			}
		}
		return Continue;
	}


	override Status enter(ir.Module m)
	{
		twf("module ");
		wf(m.name);
		wfln(";");

		return Continue;
	}

	override Status leave(ir.Module m)
	{
		return Continue;
	}

	override Status enter(ir.TopLevelBlock tlb) { return Continue; }
	override Status leave(ir.TopLevelBlock tlb) { return Continue; }

	override Status enter(ir.Import i)
	{
		twf("import ");
		if (i.bind !is null) {
			accept(i.bind, this);
			wf(" = ");
		}
		if (i.names.length == 1) {
			accept(i.names[0], this);
		} else {
			wf("[");
			foreach (idx, name; i.names) {
				accept(name, this);
				if (idx < i.names.length - 1) {
					wf(", ");
				}
			}
			wf("]");
		}
		if (i.aliases.length > 0) {
			wf(" : ");
			foreach (idx, _alias; i.aliases) {
				accept(_alias[0], this);
				if (_alias[1] !is null) {
					wf(" = ");
					accept(_alias[1], this);
				}
				if (idx < i.aliases.length - 1) {
					wf(", ");
				}
			}
		}

		wfln(";");
		return ContinueParent;
	}

	override Status leave(ir.Import i)
	{
		assert(false);
	}

	override Status enter(ir.Unittest u)
	{
		ln();
		twf("unittest {");
		ln();
		mIndent++;

		return Continue;
	}

	override Status leave(ir.Unittest u)
	{
		mIndent--;
		twfln("}");

		return Continue;
	}

	override Status enter(ir.Class c)
	{
		if (!mPrintingTemplateDefinition) {
			ln();
			twf("class ", c.name);
		}
		if (c.parent !is null || c.interfaces.length > 0) {
			wf(" : ");
			wf(c.parent);
			foreach (i, _interface; c.interfaces) {
				wf(", ");
				wf(_interface);
			}
		}
		ln();

		twf("{\n");
		mIndent++;
		foreach (member; c.members.nodes) {
			accept(member, this);
		}
		mIndent--;
		twf("}\n");

		return ContinueParent;
	}

	override Status leave(ir.Class c)
	{
		assert(false);
	}

	override Status enter(ir._Interface i)
	{
		if (!mPrintingTemplateDefinition) {
			ln();
			twf("interface ", i.name);
		}
		if (i.interfaces.length > 0) {
			wf(" : ");
			foreach (j, _interface; i.interfaces) {
				if (j > 0) {
					wf(", ");
				}
				wf(_interface);
			}
		}
		ln();

		twf("{\n");
		mIndent++;
		foreach (member; i.members.nodes) {
			accept(member, this);
		}
		mIndent--;
		twf("}\n");

		return ContinueParent;
	}

	override Status leave(ir._Interface i)
	{
		assert(false);
	}

	override Status enter(ir.Struct s)
	{
		if (!mPrintingTemplateDefinition) {
			ln();
			twf("struct ");
			wf(s.name);
		}
		ln();
		twf("{");
		ln();
		mIndent++;

		foreach (member; s.members.nodes) {
			accept(member, this);
		}

		mIndent--;
		twf("}\n");

		return ContinueParent;
	}

	override Status leave(ir.Struct s)
	{
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		if (!mPrintingTemplateDefinition) {
			ln();
			twf("union ");
			wf(u.name);
		}
		ln();
		twf("{");
		ln();
		mIndent++;

		foreach (member; u.members.nodes) {
			accept(member, this);
		}

		mIndent--;
		twf("}\n");

		return ContinueParent;
	}

	override Status leave(ir.Union u)
	{
		return Continue;
	}

	override Status enter(ir.Variable d)
	{
		twf("");
		accept(d.type, this);
		wf(" ");
		wf(d.name);
		if (d.assign !is null) {
			wf(" = ");
			acceptExp(/*#ref*/d.assign, this);
		}
		wfln(";");
		return ContinueParent;
	}

	override Status leave(ir.Variable d)
	{
		return Continue;
	}

	override Status enter(ir.FunctionParam fp)
	{
		return ContinueParent;
	}

	override Status leave(ir.FunctionParam fp)
	{
		assert(false);
	}

	override Status enter(ir.Enum e)
	{
		ln();
		twf("enum ");
		if (e.name.length > 0) {
			wf(e.name, " ");
		}
		wf(" : ");
		accept(e.base, this);
		wfln(" {");
		mIndent++;
		foreach (ref member; e.members) {
			twf(member.name);
			if (member.assign !is null) {
				wf(" = ");
				acceptExp(/*#ref*/member.assign, this);
			}
			wfln(";");
		}
		mIndent--;
		twf("}");
		return ContinueParent;
	}

	override Status leave(ir.Enum e)
	{
		assert(false);
	}

	override Status enter(ir.Attribute attr)
	{
		ln();
		final switch (attr.kind) with (ir.Attribute.Kind) {
		case Synchronized: twf("synchronized"); break;
		case Static: twf("static"); break;
		case Scope: twf("scope"); break;
		case Public: twf("public"); break;
		case Protected: twf("protected"); break;
		case Shared: twf("shared"); break;
		case Private: twf("private"); break;
		case Property: twf("@property"); break;
		case Trusted: twf("@trusted"); break;
		case System: twf("@system"); break;
		case Safe: twf("@safe"); break;
		case NoThrow: twf("nothrow"); break;
		case Override: twf("override"); break;
		case Label: twf("@label"); break;
		case Local: twf("local"); break;
		case LinkageC: twf("extern(C)"); break;
		case LinkageCPlusPlus: twf("extern(C++)"); break;
		case LinkageD: twf("extern(D)"); break;
		case LinkageVolt: twf("extern(Volt)"); break;
		case LinkageWindows: twf("extern(Windows)"); break;
		case LinkagePascal: twf("extern(Pascal)"); break;
		case LinkageSystem: twf("extern(System)"); break;
		case LoadDynamic: twf("@loadDynamic"); break;
		case Inout: twf("inout"); break;
		case Immutable: twf("immutable"); break;
		case Global: twf("global"); break;
		case Final: twf("final"); break;
		case Extern: twf("extern"); break;
		case Export: twf("export"); break;
		case Disable: twf("@disable"); break;
		case Deprecated: twf("deprecated"); break;
		case Const: twf("const"); break;
		case Auto: twf("auto"); break;
		case Abstract: twf("abstract"); break;
		case Pure: twf("pure"); break;
		case Align:
			twf("align(");
			wf(attr.alignAmount);
			wf(")");
			break;
		case MangledName:
			twf("@MangledName(");
			assert(attr.arguments.length == 1);
			acceptExp(/*#ref*/attr.arguments[0], this);
			wf(")");
			break;
		case Invalid:
			throw panicUnhandled(attr, "attribute kind");
		}

		wfln(" {");
		mIndent++;
		if (attr.members !is null) {
			foreach (member; attr.members.nodes) {
				accept(member, this);
			}
		}
		mIndent--;
		twfln("}");

		return ContinueParent;
	}

	override Status leave(ir.Attribute attr)
	{
		assert(false);
	}

	override Status enter(ir.MixinFunction mf)
	{
		ln();
		twf("mixin function ");
		twf(mf.name);
		twfln("()\n{");
		mIndent++;

		// Ok, to do this.	
		foreach (member; mf.raw.statements) {
			accept(member, this);
		}

		return Continue;
	}
	
	override Status leave(ir.MixinFunction mf)
	{
		mIndent--;
		twfln("}");
		
		return ContinueParent;
	}
	
	override Status enter(ir.MixinTemplate mt)
	{
		ln();
		twf("mixin template ");
		twf(mt.name);
		twf("()");
		ln();
		twf("{");
		ln();
		mIndent++;

		// Ok, to do this.	
		foreach (member; mt.raw.nodes) {
			accept(member, this);
		}
		
		return Continue;
	}

	override Status leave(ir.MixinTemplate mt)
	{
		mIndent--;
		twf("}\n");

		return ContinueParent;
	}

	override Status enter(ir.Condition c)
	{
		final switch (c.kind) with (ir.Condition.Kind) {
		case Debug:
			twf("debug ");
			if (c.exp !is null) {
				wf("(");
				acceptExp(/*#ref*/c.exp, this);
				wf(")");
			}
			return ContinueParent;
		case Version:
			twf("version (");
			break;
		case StaticIf:
			twf("static if (");
			break;
		case Invalid:
			throw panicUnhandled(c, "condition");
		}
		acceptExp(/*#ref*/c.exp, this);
		wf(")");
		return ContinueParent;
	}

	override Status leave(ir.Condition c)
	{
		assert(false);
	}

	override Status enter(ir.ConditionTopLevel ctl)
	{
		ln();
		accept(ctl.condition, this);
		wfln(" {");
		mIndent++;
		foreach (member; ctl.members.nodes) {
			accept(member, this);
		}
		mIndent--;
		twf("}");
		if (ctl.elsePresent) {
			wfln(" else {");
			mIndent++;
			foreach (member; ctl._else.nodes) {
				accept(member, this);
			}
			mIndent--;
			twfln("}");
		} else {
			ln();
		}
		return ContinueParent;
	}

	override Status leave(ir.ConditionTopLevel ctl)
	{
		assert(false);
	}

	/*
	 *
	 * Statement Nodes.
	 *
	 */

	override Status enter(ir.ExpStatement e)
	{
		twf("");
		acceptExp(/*#ref*/e.exp, this);
		wfln(";");
		return ContinueParent;
	}

	override Status leave(ir.ExpStatement e)
	{
		assert(false);
	}

	override Status enter(ir.ReturnStatement ret)
	{
		twf("return ");
		return Continue;
	}

	override Status leave(ir.ReturnStatement ret)
	{
		wfln(";");
		return Continue;
	}

	override Status enter(ir.BlockStatement b)
	{
		twf("{");
		ln();
		mIndent++;
		return Continue;
	}

	override Status leave(ir.BlockStatement b)
	{
		mIndent--;
		twf("}");
		ln();
		return Continue;
	}

	override Status enter(ir.AsmStatement a)
	{
		twf("asm {");
		ln();
		mIndent++;
		twf("");
		foreach (token; a.tokens) {
			if (token.type == TokenType.Semicolon) {
				wf(";");
				ln();
				twf("");
			} else {
				wf(" ");
				wf(token.value);
			}
		}
		ln();
		mIndent--;
		twf("}");

		return ContinueParent;
	}

	override Status leave(ir.AsmStatement a)
	{
		return Continue;
	}

	override Status enter(ir.IfStatement i)
	{
		twf("if ");
		wf("(");
		if (i.autoName.length > 0) {
			wf("auto ");
			wf(i.autoName);
			wf(" = ");
		}
		acceptExp(/*#ref*/i.exp, this);
		wf(") {");
		mIndent++;
		ln();
		internalPrintBlock(i.thenState);
		mIndent--;
		twf("}");
		if (i.elseState !is null) {
			wf(" else {");
			mIndent++;
			ln();
			internalPrintBlock(i.elseState);
			mIndent--;
			twf("}");
		}
		ln();
		return ContinueParent;
	}

	override Status leave(ir.IfStatement i)
	{
		assert(false);
	}

	override Status enter(ir.WhileStatement w)
	{
		twf("while ");
		wf("(");
		acceptExp(/*#ref*/w.condition, this);
		wf(") {");
		mIndent++;
		ln();
		internalPrintBlock(w.block);
		mIndent--;
		twf("}");
		ln();
		return ContinueParent;
	}

	override Status leave(ir.WhileStatement w)
	{
		assert(false);
	}

	override Status enter(ir.DoStatement d)
	{
		twf("do {");
		mIndent++;
		ln();
		internalPrintBlock(d.block);
		mIndent--;
		twf("} while (");
		acceptExp(/*#ref*/d.condition, this);
		wf(");");
		ln();

		return ContinueParent;
	}

	override Status leave(ir.DoStatement d)
	{
		assert(false);
	}

	override Status enter(ir.ForeachStatement fes)
	{
		fes.reverse ? twf("foreach_reverse (") : twf("foreach (");
		foreach (i, v; fes.itervars) {
			accept(v.type, this);
			wf(" ");
			wf(v.name);
			if (i < fes.itervars.length - 1) {
				wf(", ");
			}
		}
		wf("; ");
		if (fes.beginIntegerRange !is null) {
			acceptExp(/*#ref*/fes.beginIntegerRange, this);
			wf(" .. ");
			acceptExp(/*#ref*/fes.endIntegerRange, this);
		} else {
			acceptExp(/*#ref*/fes.aggregate, this);
		}
		wfln(") {");
		mIndent++;
		internalPrintBlock(fes.block);
		mIndent--;
		twfln("}");
		return ContinueParent;
	}

	override Status leave(ir.ForeachStatement fes)
	{
		assert(false);
	}

	override Status enter(ir.ForStatement f)
	{
		twf("for (");

		auto oldIndent = mIndent;
		mIndent = 0;

		if (f.initExps.length > 0) {
			foreach (index, ref i; f.initExps) {
				acceptExp(/*#ref*/i, this);
				if (index < f.initExps.length - 1) {
					wf(", ");
				}
			}
		} else if (f.initVars.length > 0) {
			auto asDecl = f.initVars[0];
			assert(asDecl !is null);
			accept(asDecl.type, this);
			wf(" ");
			foreach (i, d; f.initVars) {
				wf(d.name);
				if (d.assign !is null) {
					wf(" = ");
					acceptExp(/*#ref*/d.assign, this);
				}
				if (i < f.initVars.length - 1) {
					wf(", ");
				}
			}
		}
		wf(";");
		if (f.test !is null) {
			wf(" ");
			acceptExp(/*#ref*/f.test, this);
		}
		wf(";");
		if (f.increments.length > 0) {
			wf(" ");
			foreach (i, ref increment; f.increments) {
				acceptExp(/*#ref*/increment, this);
				if (i < f.increments.length - 1) {
					wf(", ");
				}
			}
		}
		wf(") {");
		mIndent = oldIndent + 1;
		ln();

		internalPrintBlock(f.block);

		mIndent--;
		twf("}");
		ln();
		return ContinueParent;
	}

	override Status leave(ir.ForStatement f)
	{
		assert(false);
	}

	override Status enter(ir.SwitchStatement ss)
	{
		if (ss.isFinal) {
			twf("final switch (");
		} else {
			twf("switch (");
		}
		acceptExp(/*#ref*/ss.condition, this);
		wfln(") {");
		foreach (_case; ss.cases) {
			accept(_case, this);
		}
		twfln("}");
		return ContinueParent;
	}

	override Status leave(ir.SwitchStatement ss)
	{
		assert(false);
	}

	override Status enter(ir.SwitchCase sc)
	{
		if (sc.isDefault) {
			twfln("default:");
		} else {
			twf("case ");
			if (sc.firstExp !is null && sc.secondExp is null) {
				acceptExp(/*#ref*/sc.firstExp, this);
				wfln(":");
			} else if (sc.firstExp !is null && sc.secondExp !is null) {
				acceptExp(/*#ref*/sc.firstExp, this);
				wf(": .. case ");
				acceptExp(/*#ref*/sc.secondExp, this);
				wfln(":");
			} else if (sc.exps.length > 0) {
				foreach (i, exp; sc.exps) {
					acceptExp(/*#ref*/exp, this);
					if (i < sc.exps.length - 1) {
						wf(", ");
					}
				}
				wfln(":");
			} else {
				throw panic(/*#ref*/sc.loc, "unknown case type passed to PrintVisitor.");
			}
		}
		mIndent++;
		foreach (statement; sc.statements.statements) {
			accept(statement, this);
			if (statement.nodeType == ir.NodeType.Variable) {
				// Ew.
				ln();
			}
		}
		mIndent--;

		return ContinueParent;
	}

	override Status leave(ir.SwitchCase sc)
	{
		assert(false);
	}

	override Status enter(ir.LabelStatement ls)
	{
		wf(format("%s:", ls.label, ":"));
		ln();
		return Continue;
	}

	override Status leave(ir.LabelStatement ls)
	{
		return Continue;
	}

	override Status visit(ir.ContinueStatement cs)
	{
		twf("continue");
		if (cs.label.length > 0) {
			wf(" ");
			wf(cs.label);
		}
		wfln(";");

		return Continue;
	}

	override Status visit(ir.BreakStatement bs)
	{
		twf("break");
		if (bs.label.length > 0) {
			wf(" ");
			wf(bs.label);
		}
		wfln(";");

		return Continue;
	}

	override Status enter(ir.GotoStatement gs)
	{
		twf("goto ");
		if (gs.label.length > 0) {
			wf(gs.label);
		} else if (gs.isDefault) {
			wf("default");
		} else if (gs.isCase) {
			wf("case");
			if (gs.exp !is null) {
				wf(" ");
				acceptExp(/*#ref*/gs.exp, this);
			}
		} else {
			throw panic(/*#ref*/gs.loc, "malformed goto statement made it to PrintVisitor.");
		}
		wfln(";");

		return ContinueParent;
	}

	override Status leave(ir.GotoStatement gs)
	{
		assert(false);
	}

	override Status enter(ir.WithStatement ws)
	{
		twf("with (");
		acceptExp(/*#ref*/ws.exp, this);
		wfln(") {");
		mIndent++;
		internalPrintBlock(ws.block);
		mIndent--;
		twfln("}");

		return ContinueParent;
	}

	override Status leave(ir.WithStatement ws)
	{
		assert(false);
	}

	override Status enter(ir.SynchronizedStatement ss)
	{
		twf("synchronized ");
		if (ss.exp !is null) {
			wf("(");
			acceptExp(/*#ref*/ss.exp, this);
			wf(") ");
		}
		wfln("{");
		mIndent++;
		internalPrintBlock(ss.block);
		mIndent--;
		twfln("}");

		return ContinueParent;
	}

	override Status leave(ir.SynchronizedStatement ss)
	{
		assert(false);
	}

	override Status enter(ir.TryStatement ts)
	{
		twfln("try {");
		mIndent++;
		internalPrintBlock(ts.tryBlock);
		mIndent--;
		twf("} ");

		foreach (i, cb; ts.catchBlocks) {
			auto v = ts.catchVars[i];
			wf("catch(");
			accept(v.type, this);
			wf(" ");
			wf(v.name);
			wfln(") {");
			mIndent++;
			internalPrintBlock(cb);
			mIndent--;
			twf("} ");
		}

		if (ts.finallyBlock !is null) {
			wfln("finally {");
			mIndent++;
			internalPrintBlock(ts.finallyBlock);
			mIndent--;
			twf("}");
		}

		ln();

		return ContinueParent;
	}


	override Status leave(ir.TryStatement ts)
	{
		assert(false);
	}

	override Status enter(ir.ThrowStatement ts)
	{
		twf("throw ");
		acceptExp(/*#ref*/ts.exp, this);
		wfln(";");
		return ContinueParent;
	}

	override Status leave(ir.ThrowStatement ts)
	{
		assert(false);
	}

	override Status enter(ir.ScopeStatement ss)
	{
		twf("scope (");
		final switch (ss.kind) with (ir.ScopeKind) {
		case Exit: wfln("exit) {"); break;
		case Success: wfln("success) {"); break;
		case Failure: wfln("failure) {"); break;
		}
		mIndent++;
		internalPrintBlock(ss.block);
		mIndent--;
		twfln("}");
		return ContinueParent;
	}

	override Status leave(ir.ScopeStatement ss)
	{
		assert(false);
	}

	override Status enter(ir.PragmaStatement ps)
	{
		twf("pragma(");
		wf(ps.type);
		if (ps.arguments.length > 0) {
			foreach (i, ref arg; ps.arguments) {
				if (i < ps.arguments.length - 1) {
					wf(", ");
				}
				acceptExp(/*#ref*/arg, this);
			}
		}
		wfln(") {");
		mIndent++;
		internalPrintBlock(ps.block);
		mIndent--;
		twfln("}");
		return ContinueParent;
	}

	override Status leave(ir.PragmaStatement ps)
	{
		assert(false);
	}

	override Status enter(ir.ConditionStatement cs)
	{
		accept(cs.condition, this);

		wfln(" {");
		mIndent++;
		internalPrintBlock(cs.block);
		mIndent--;
		twf("}");

		if (cs._else !is null) {
			wfln(" else {");
			mIndent++;
			internalPrintBlock(cs._else);
			mIndent--;
			twfln("}");
		} else {
			ln();
		}

		return ContinueParent;
	}

	override Status leave(ir.ConditionStatement cs)
	{
		assert(false);
	}

	override Status enter(ir.AssertStatement as)
	{
		if (as.isStatic) {
			wf("static ");
		}
		wf("assert(");
		acceptExp(/*#ref*/as.condition, this);
		if (as.message !is null) {
			wf(", ");
			acceptExp(/*#ref*/as.message, this);
		}
		wfln(");");
		return ContinueParent;
	}

	override Status leave(ir.AssertStatement as)
	{
		assert(false);
	}
	
	override Status enter(ir.MixinStatement ms)
	{
		if (ms.id !is null) {
			wf("mixin ", ms.id.identifiers[0].value, "!();");
		}
		if (ms.stringExp !is null) {
			wf("mixin (");
			
			auto oldIndentText = mIndentText;
			mIndentText = "";
			
			acceptExp(/*#ref*/ms.stringExp, this);
			
			mIndentText = oldIndentText;
			
			wfln(");");
		}

		if (ms.resolved !is null) {
			foreach (s; ms.resolved.statements)
				accept(s, this);
		}

		return ContinueParent;
	}
	
	override Status leave(ir.MixinStatement ms) { return Continue; }
	
	/*
	 *
	 * Declarations.
	 *
	 */

	override Status enter(ir.EnumDeclaration ed)
	{
		wf("enum");
		if (ed.type !is null) {
			wf(" ");
			accept(ed.type, this);
		}
		wf(" ", ed.name);
		if (ed.assign !is null) {
			wf(" = ");
			acceptExp(/*#ref*/ed.assign, this);
		}
		wfln(";");
		return ContinueParent;
	}

	override Status leave(ir.EnumDeclaration ed)
	{
		assert(false);
	}

	override Status enter(ir.PointerType pointer)
	{
		wStorageTypes(pointer);
		accept(pointer.base, this);
		wf("*");
		wAfterStorageTypes(pointer);
		return ContinueParent;
	}

	override Status leave(ir.PointerType pointer)
	{
		return Continue;
	}

	override Status visit(ir.NullType nullType)
	{
		return Continue;
	}

	override Status enter(ir.ArrayType array)
	{
		wStorageTypes(array);
		accept(array.base, this);
		wf("[]");
		wAfterStorageTypes(array);
		return ContinueParent;
	}

	override Status leave(ir.ArrayType array)
	{
		return Continue;
	}

	override Status enter(ir.StaticArrayType array)
	{
		wStorageTypes(array);
		accept(array.base, this);
		wf("[");
		wf(array.length);
		wf("]");
		wAfterStorageTypes(array);
		return ContinueParent;
	}

	override Status leave(ir.StaticArrayType array)
	{
		return Continue;
	}

	override Status enter(ir.AmbiguousArrayType array)
	{
		wStorageTypes(array);
		accept(array.base, this);
		wf("[");
		acceptExp(/*#ref*/array.child, this);
		wf("]");
		wAfterStorageTypes(array);
		return ContinueParent;
	}

	override Status leave(ir.AmbiguousArrayType array)
	{
		return Continue;
	}

	override Status enter(ir.AAType array)
	{
		wStorageTypes(array);
		accept(array.value, this);
		wf("[");
		accept(array.key, this);
		wf("]");
		wAfterStorageTypes(array);
		return ContinueParent;
	}

	override Status enter(ir.FunctionType func)
	{
		accept(func.ret, this);
		wf(" function(");
		foreach (i, param; func.params) {
			if (func.isArgRef[i]) {
				wf("ref ");
			}
			if (func.isArgOut[i]) {
				wf("out ");
			}
			accept(param, this);
			if (i < func.params.length - 1) {
				wf(", ");
			}
		}
		if (func.hasVarArgs) {
			wf(", ...");
		}
		wf(")");
		return ContinueParent;
	}

	override Status leave(ir.FunctionType func)
	{
		return Continue;
	}

	override Status enter(ir.DelegateType func)
	{
		accept(func.ret, this);
		wf(" delegate(");
		foreach (i, param; func.params) {
			if (func.isArgRef[i]) {
				wf("ref ");
			}
			if (func.isArgOut[i]) {
				wf("out ");
			}
			accept(param, this);
			if (i < func.params.length - 1) {
				wf(", ");
			}
		}
		if (func.hasVarArgs) {
			wf(", ...");
		}
		wf(")");
		return ContinueParent;
	}

	override Status leave(ir.DelegateType func)
	{
		return Continue;
	}

	override Status leave(ir.AAType array)
	{
		return Continue;
	}
	
	override Status enter(ir.Function func)
	{
		if (!mPrintingTemplateDefinition) {
			ln();
			twf("");

			if (func.mangledName !is null) {
				wf("@mangledName(\"");
				wf(func.mangledName);
				wfln("\")");
				twf("");
			}

			final switch(func.kind) with (ir.Function.Kind) {
			case LocalMember:
				wf("local ");
				goto case Member;
			case GlobalMember:
			case GlobalNested:
				wf("global ");
				goto case Member;
			case Invalid:
			case Function:
			case Nested:
			case Member:
				accept(func.type.ret, this);
				wf(" ");
				wf(func.name);
				wf("(");
				break;
			case Constructor:
				wf("this(");
				break;
			case Destructor:
				wf("~this(");
				break;
			case LocalConstructor:
				wf("local this(");
				break;
			case LocalDestructor:
				wf("local ~this(");
				break;
			case GlobalConstructor:
				wf("global this(");
				break;
			case GlobalDestructor:
				wf("global ~this(");
				break;
			}
		}

		foreach (i, param; func.params) {
			if (func.type.isArgRef[i]) {
				wf("ref ");
			}
			if (func.type.isArgOut[i]) {
				wf("out ");
			}
			accept(param.type, this);
			if (param.name.length > 0) {
				wf(" ");
				wf(param.name);
			}
			if (i < func.type.params.length - 1) {
				wf(", ");
			}
		}
		if (func.type.hasVarArgs) {
			wf(", ...");
		}
		wf(")");

		void printNodes(ir.Node[] nodes)
		{
			mIndent++;
			foreach (node; nodes) {
				accept(node, this);
			}
			mIndent--;
		}

		void printTokens(ir.Token[] tokens)
		{
			mIndent++;
			if (tokens.length <= 4) {
				return;
			}
			// Skip, BEGIN { } END tokens.
			auto inFor = false;
			auto newLine = false;
			auto parenDepth = 0;
			t();
			foreach (i, token; tokens[2 .. $-2]) {
				auto isFirstTokenForLine = i == 0 || newLine;
				if (newLine) {
					wf("\n");
					if (token.type == TokenType.CloseBrace) {
						mIndent--;
					}
					t();
					newLine = false;
				}
				if (token.type == TokenType.For || token.type == TokenType.Foreach) {
					inFor = true;
					parenDepth = 0;
				}
				if (token.type == TokenType.OpenParen) {
					parenDepth++;
				} else if (token.type == TokenType.CloseParen) {
					parenDepth--;
				}
				if (inFor && token.type != TokenType.For && token.type != TokenType.Foreach && parenDepth == 0) {
					inFor = false;
				}
				switch (token.type) {
				case TokenType.Colon, TokenType.Semicolon:
					break;
				default:
					if (!isFirstTokenForLine) {
						wf(" ");
					}
				}
				wf(token.value);
				if (token.type == TokenType.Semicolon && !inFor) {
					newLine = true;
				} else if (token.type == TokenType.OpenBrace) {
					mIndent++;
					newLine = true;
				} else if (token.type == TokenType.CloseBrace) {
					newLine = true;
				}
			}
			mIndent--;
		}

		if (func.hasInContract) {
			ln();
			twfln("in {");
			if (func.parsedIn is null) {
				printTokens(func.tokensIn);
			} else {
				printNodes(func.parsedIn.statements);
			}
			ln();
			twfln("}");
		}

		if (func.hasOutContract) {
			if (func.outParameter.length > 0) {
				twfln(format("out (%s) {", func.outParameter));
			} else {
				twfln("out {");
			}
			if (func.parsedOut is null) {
				printTokens(func.tokensOut);
			} else {
				printNodes(func.parsedOut.statements);
			}
			ln();
			twfln("}");
		}

		if (func.hasBody) {
			if (func.hasInContract || func.hasOutContract) {
				twfln("body {");
			} else {
				ln();
				twfln("{");
			}

			if (func.parsedBody is null) {
				printTokens(func.tokensBody);
			} else {
				printNodes(func.parsedBody.statements);
			}

			ln();
			twfln("}");
		} else {
			wfln(";");
		}

		return ContinueParent;
	}

	override Status leave(ir.Function func)
	{
		return Continue;
	}

	override Status enter(ir.StorageType type)
	{
		final switch (type.type) with (ir.StorageType.Kind) {
		case Auto: wf("auto("); break;
		case Const: wf("const("); break;
		case Immutable: wf("immutable("); break;
		case Scope: wf("scope ("); break;
		case Ref: wf("ref("); break;
		case Out: wf("out("); break;
		case Invalid:
			throw panicUnhandled(type, "storagetype");
		}
		if (type.base !is null) {
			accept(type.base, this);
		}
		wf(")");
		return ContinueParent;
	}

	override Status leave(ir.StorageType type)
	{
		assert(false);
	}

	override Status visit(ir.AutoType at)
	{
		if (at.explicitType !is null) {
			return accept(at.explicitType, this);
		}
		if (at.isConst) {
			wf("const");
		} else if (at.isImmutable) {
			wf("immutable");
		} else if (at.isScope) {
			wf("scope");
		} else {
			wf("auto");
		}
		return Continue;
	}

	override Status visit(ir.NoType at)
	{
		wf("<NoType>");
		return Continue;
	}

	override Status enter(ir.AliasStaticIf asi)
	{
		wf("static if (");
		foreach (i, ref condition; asi.conditions) {
			acceptExp(/*#ref*/condition, this);
			wfln(") {");
			mIndent++;
			twf();
			accept(asi.types[i], this);
			wfln(";");
			mIndent--;
			twf("} ");
			if (i < asi.conditions.length - 1) {
				wf("else if ");
			}
		}
		if (asi.types.length > asi.conditions.length) {
			wfln("else {");
			mIndent++;
			twf();
			accept(asi.types[$-1], this);
			wfln(";");
			mIndent--;
			twfln("}");
		} else {
			wfln("");
		}
		return ContinueParent;
	}

	override Status leave(ir.AliasStaticIf asi)
	{
		assert(false);
	}

	override Status enter(ir.Alias a)
	{
		ln();
		twf("alias ");
		wf(a.name);
		wf(" = ");
		if (a.type !is null) {
			accept(a.type, this);
		} else if (a.id !is null) {
			accept(a.id, this);
		} else if (a.staticIf !is null) {
			accept(a.staticIf, this);
		} else {
			wf("null");
		}
		wfln(";");
		return ContinueParent;
	}

	override Status leave(ir.Alias a)
	{
		assert(false);
	}

	override Status enter(ir.TypeOf typeOf)
	{
		wf("typeof(");
		acceptExp(/*#ref*/typeOf.exp, this);
		wf(")");
		return ContinueParent;
	}

	override Status leave(ir.TypeOf typeOf)
	{
		assert(false);
	}

	/*
	 *
	 * Template Nodes.
	 *
	 */

	override Status enter(ir.TemplateInstance ti)
	{
		wf(" = ");
		wf(ti.definitionName);
		wf("!(");
		foreach (i, arg; ti.arguments) {
			auto exp = cast(ir.Exp)arg;
			if (exp is null) {
				accept(arg, this);
			} else {
				acceptExp(/*#ref*/exp, this);
			}
			if (i < ti.arguments.length - 1) {
				wf(", ");
			}
		}
		wf(");");
		return ContinueParent;
	}

	override Status leave(ir.TemplateInstance ti)
	{
		assert(false);
	}

	override Status visit(ir.TemplateDefinition td)
	{
		ln();
		final switch (td.kind) with (ir.TemplateKind) {
		case Struct: wf("struct "); break;
		case Union: wf("union "); break;
		case Interface: wf("interface "); break;
		case Class: wf("class "); break;
		case Function: wf("fn "); break;
		}
		wf(td.name);
		wf("!(");
		foreach (i, param; td.parameters) {
			wf(param.name);
			if (i < td.parameters.length - 1) {
				wf(", ");
			}
		}
		wf(")");
		mPrintingTemplateDefinition++;
		final switch (td.kind) with (ir.TemplateKind) {
		case Struct: accept(td._struct, this); break;
		case Union: accept(td._union, this); break;
		case Interface: accept(td._interface, this); break;
		case Class: accept(td._class, this); break;
		case Function: accept(td._function, this); break;
		}
		mPrintingTemplateDefinition--;
		return Continue;
	}

	/*
	 *
	 * Expression Nodes.
	 *
	 */


	override Status enter(ref ir.Exp, ir.Constant constant)
	{
		auto asPrim = cast(ir.PrimitiveType) constant.type;
		if (asPrim !is null) {
			switch (asPrim.type) with (ir.PrimitiveType.Kind) {
			case Bool: wf(.toString(constant.u._bool)); break;
			case Uint: wf(constant.u._uint); break;
			case Int: wf(constant.u._int); break;
			case Long: wf(constant.u._long); break;
			case Ulong: wf(constant.u._ulong); break;
			default: wf(constant._string); break;
			}
		} else {
			wf(constant._string);
		}
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.Constant)
	{
		assert(false);
	}

	override Status visit(ref ir.Exp, ir.IdentifierExp identifier)
	{
		if (identifier.globalLookup) {
			wf(".");
		}
		wf(identifier.value);
		return Continue;
	}

	override Status enter(ref ir.Exp, ir.ArrayLiteral array)
	{
		wf("[");
		foreach (i, exp; array.exps) {
			acceptExp(/*#ref*/exp, this);
			if (i < array.exps.length - 1) {
				wf(", ");
			}
		}
		wf("]");
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.ArrayLiteral array)
	{
		return Continue;
	}

	override Status enter(ref ir.Exp, ir.AssocArray array)
	{
		wf("[");
		foreach (i, ref pair; array.pairs) {
			acceptExp(/*#ref*/pair.key, this);
			wf(":");
			acceptExp(/*#ref*/pair.value, this);
			if (i < array.pairs.length - 1) {
				wf(", ");
			}
		}
		wf("]");
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.AssocArray array)
	{
		return Continue;
	}

	override Status enter(ref ir.Exp, ir.Assert _assert)
	{
		wf("assert(");
		acceptExp(/*#ref*/_assert.condition, this);
		if (_assert.message !is null) {
			wf(", ");
			acceptExp(/*#ref*/_assert.message, this);
		}
		wf(")");
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.Assert _assert)
	{
		return Continue;
	}

	override Status enter(ref ir.Exp, ir.StringImport strimport)
	{
		wf("import(");
		acceptExp(/*#ref*/strimport.filename, this);
		wf(")");
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.StringImport strimport)
	{
		return Continue;
	}

	override Status enter(ref ir.Exp, ir.Ternary ternary)
	{
		acceptExp(/*#ref*/ternary.condition, this);
		wf(" ? ");
		acceptExp(/*#ref*/ternary.ifTrue, this);
		wf(" : ");
		acceptExp(/*#ref*/ternary.ifFalse, this);
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.Ternary ternary)
	{
		return Continue;
	}

	override Status enter(ref ir.Exp, ir.BinOp binop)
	{
		wf("(");

		acceptExp(/*#ref*/binop.left, this);
		wf(" ");
		wf(binopToString(binop.op));
		wf(" ");
		acceptExp(/*#ref*/binop.right, this);

		wf(")");

		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.BinOp binop)
	{
		return Continue;
	}

	override Status enter(ref ir.Exp, ir.Unary unary)
	{
		final switch (unary.op) {
		case ir.Unary.Op.AddrOf: wf("&"); break;
		case ir.Unary.Op.Increment: wf("++"); break;
		case ir.Unary.Op.Decrement: wf("--"); break;
		case ir.Unary.Op.Dereference: wf("*"); break;
		case ir.Unary.Op.Minus: wf("-"); break;
		case ir.Unary.Op.Plus: wf("+"); break;
		case ir.Unary.Op.Not: wf("!"); break;
		case ir.Unary.Op.Complement: wf("~"); break;
		case ir.Unary.Op.Cast:
			wf("cast(");
			accept(unary.type, this);
			wf(")");
			break;
		case ir.Unary.Op.New:
			wf("new ");
			accept(unary.type, this);
			if (unary.hasArgumentList) {
				wf("(");
				foreach (i, ref arg; unary.argumentList) {
					acceptExp(/*#ref*/arg, this);
					if (i < unary.argumentList.length - 1) {
						wf(", ");
					}
					wf(")");
				}
			}
			break;
		case ir.Unary.Op.TypeIdent:
			wf("typeid(");
			if (unary.value !is null) {
				acceptExp(/*#ref*/unary.value, this);
			} else if (unary.type !is null) {
				accept(unary.type, this);
			} else {
				assert(false);
			}
			wf(")");
			break;
		case ir.Unary.Op.Dup:
			wf("(");
			acceptExp(/*#ref*/unary.value, this);
			wf(").dup");
			break;
		case ir.Unary.Op.None:
			throw panicUnhandled(unary, "unary op");
		}

		if (unary.value !is null) {
			acceptExp(/*#ref*/unary.value, this);
		}

		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.Unary unary)
	{
		assert(false);
	}

	override Status leave(ref ir.Exp, ir.Postfix postfix)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp, ir.Postfix postfix)
	{
		if (postfix.child !is null) {
			acceptExp(/*#ref*/postfix.child, this);
		}
		switch (postfix.op) {
		case ir.Postfix.Op.Identifier:
			wf(".");
			wf(postfix.identifier.value);
			break;
		case ir.Postfix.Op.Increment:
			wf("++");
			break;
		case ir.Postfix.Op.Decrement:
			wf("--");
			break;
		case ir.Postfix.Op.Index:
			wf("[");
			foreach (i, ref arg; postfix.arguments) {
				acceptExp(/*#ref*/arg, this);
				if (i < postfix.arguments.length - 1) {
					wf(", ");
				}
			}
			wf("]");
			break;
		case ir.Postfix.Op.Slice:
			wf("[");
			switch (postfix.arguments.length) {
			case 0:
				break;
			case 1:
				acceptExp(/*#ref*/postfix.arguments[0], this);
				break;
			case 2:
				acceptExp(/*#ref*/postfix.arguments[0], this);
				wf("..");
				acceptExp(/*#ref*/postfix.arguments[1], this);
				break;
			default:
				throw panic(/*#ref*/postfix.loc, "bad slice.");
			}
			wf("]");
			break;
		case ir.Postfix.Op.Call:
			wf("(");
			foreach (i, arg; postfix.arguments) {
				acceptExp(/*#ref*/arg, this);
				if (i < postfix.arguments.length - 1) {
					wf(", ");
				}
			}
			wf(")");
			break;
		case ir.Postfix.Op.CreateDelegate:
			wf(".");
			ir.ExpReference eref = cast(ir.ExpReference) postfix.memberFunction;
			assert(eref !is null);
			wf(eref.idents);
			break;
		default:
			throw panic(/*#ref*/postfix.loc, "tried to print bad postfix expression.");
		}

		return ContinueParent;
	}

	override Status enter(ref ir.Exp exp, ir.PropertyExp prop)
	{
		if (prop.child !is null) {
			acceptExp(/*#ref*/prop.child, this);
			wf(".");
		}
		wf(prop.identifier.value);
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.PropertyExp)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp exp, ir.BuiltinExp inbuilt)
	{
		wf("<builtin:");
		final switch (inbuilt.kind) with (ir.BuiltinExp.Kind) {
		case Invalid: wf("INVALID"); break;
		case ArrayPtr: wf("array.ptr"); break;
		case ArrayLength: wf("array.length"); break;
		case ArrayDup: wf("array.dup"); break;
		case AALength: wf("aa.length"); break;
		case AAKeys: wf("aa.keys"); break;
		case AAValues: wf("aa.values"); break;
		case AARehash: wf("aa.rehash"); break;
		case AAGet: wf("aa.get"); break;
		case AARemove: wf("aa.remove"); break;
		case AAIn: wf("aa.in"); break;
		case AADup: wf("aa.dup"); break;
		case UFCS: wf("ufcs"); break;
		case Classinfo: wf("classinfo"); break;
		case PODCtor: wf("podctor"); break;
		case VaStart: wf("va_start"); break;
		case VaArg: wf("va_arg"); break;
		case VaEnd: wf("va_end"); break;
		case BuildVtable: wf("build_vtable"); break;
		case EnumMembers: wf("enum_members"); break;
		}
		wf(">(");
		auto arr = inbuilt.children;
		foreach (i, ref c; arr) {
			acceptExp(/*#ref*/c, this);
			if (i < arr.length - 1) {
				wf(", ");
			}
		}
		wf(")");
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.BuiltinExp)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp exp, ir.AccessExp ae)
	{
		acceptExp(/*#ref*/ae.child, this);
		wf(".");
		wf(ae.field.name);
		return ContinueParent;
	}

	override Status leave(ref ir.Exp exp, ir.AccessExp ae)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp exp, ir.RunExp runexp)
	{
		wf("#run");
		acceptExp(/*#ref*/runexp.child, this);
		return ContinueParent;
	}

	override Status leave(ref ir.Exp exp, ir.RunExp runexp)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp exp, ir.ComposableString cs)
	{
		wf("\"");
		foreach (ref component; cs.components) {
			wf("${");
			acceptExp(/*#ref*/component, this);
			wf("}");
		}
		wf("\"");
		return ContinueParent;
	}

	override Status leave(ref ir.Exp exp, ir.ComposableString cs)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp, ir.Typeid ti)
	{
		wf("typeid(");
		if (ti.exp !is null) {
			acceptExp(/*#ref*/ti.exp, this);
		} else {
			accept(ti.type, this);
		}
		wf(")");
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.Typeid ti)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp, ir.IsExp isExp)
	{
		wf("is(");
		accept(isExp.type, this);
		if (isExp.compType != ir.IsExp.Comparison.None) {
			if (isExp.compType == ir.IsExp.Comparison.Implicit) {
				wf(" : ");
			} else {
				assert(isExp.compType == ir.IsExp.Comparison.Exact);
				wf(" == ");
			}
			final switch (isExp.specialisation) with (ir.IsExp.Specialisation) {
			case None:
				assert(false);
			case Type:
				assert(isExp.specType !is null);
				accept(isExp.specType, this);
				break;
			case Struct: wf("struct"); break;
			case Union: wf("union"); break;
			case Class: wf("class"); break;
			case Interface: wf("interface"); break;
			case Function: wf("function"); break;
			case Enum: wf("enum"); break;
			case Delegate: wf("delegate"); break;
			case Super: wf("super"); break;
			case Const: wf("const"); break;
			case Immutable: wf("immutable"); break;
			case Inout: wf("inout"); break;
			case Shared: wf("shared"); break;
			case Return: wf("return"); break;
			}
		}
		wf(")");
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.IsExp isExp)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp, ir.FunctionLiteral functionLiteral)
	{
		void printParams() {
			foreach (i, param; functionLiteral.params) {
				accept(param.type, this);
				if (param.name.length > 0) {
					wf(" ", param.name);
				}
				if (i < functionLiteral.params.length - 1) {
					wf(", ");
				}
			}
		}

		if (functionLiteral.lambdaExp !is null) {
			if (functionLiteral.singleLambdaParam.length > 0) {
				wf(functionLiteral.singleLambdaParam);
			} else {
				wf("(");
				printParams();
				wf(")");
			}
			wf(" => ");
			acceptExp(/*#ref*/functionLiteral.lambdaExp, this);
			return ContinueParent;
		}

		if (functionLiteral.isDelegate) {
			wf("delegate ");
		} else {
			wf("function ");
		}

		if (functionLiteral.returnType !is null) {
			accept(functionLiteral.returnType, this);
		}
		wf("(");
		printParams();
		wfln(") {");
		mIndent++;
		foreach (statement; functionLiteral.block.statements) {
			accept(statement, this);
		}
		mIndent--;
		twf("}");

		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.FunctionLiteral functionLiteral)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp, ir.StructLiteral sliteral)
	{
		wf("{ ");
		foreach (i, exp; sliteral.exps) {
			acceptExp(/*#ref*/exp, this);
			if (i < sliteral.exps.length - 1) {
				wf(", ");
			}
		}
		wf("}");

		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.StructLiteral sliteral)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp, ir.UnionLiteral sliteral)
	{
		wf("{ ");
		foreach (i, exp; sliteral.exps) {
			acceptExp(/*#ref*/exp, this);
			if (i < sliteral.exps.length - 1) {
				wf(", ");
			}
		}
		wf("}");

		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.UnionLiteral sliteral)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp, ir.ClassLiteral cliteral)
	{
		wf("{ ");
		foreach (i, ref exp; cliteral.exps) {
			acceptExp(/*#ref*/exp, this);
			if (i < cliteral.exps.length - 1) {
				wf(", ");
			}
		}
		wf("}");

		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.ClassLiteral cliteral)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp, ir.TypeExp texp)
	{
		accept(texp.type, this);
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.TypeExp texp)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp, ir.StatementExp statExp)
	{
		wfln("({");
		mIndent++;
		foreach (stat; statExp.statements) {
			accept(stat, this);
		}
		if (statExp.exp !is null) {
			twf("");
			acceptExp(/*#ref*/statExp.exp, this);
			wf(" })");
		}
		mIndent--;
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.StatementExp state)
	{
		assert(false);
	}

	override Status enter(ref ir.Exp, ir.VaArgExp vaexp)
	{
		wf("va_arg!(");
		accept(vaexp.type, this);
		wf(")(");
		acceptExp(/*#ref*/vaexp.arg, this);
		wf(")");
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.VaArgExp vaexp)
	{
		assert(false);
	}

	override Status visit(ref ir.Exp, ir.ExpReference e)
	{ 
		if (e.idents.length > 1) for (size_t i = e.idents.length - 1; i > 0; --i) {
			wf(e.idents[i]);
			if (i > 1) {
				wf(".");
			}
		} else if (e.idents.length == 1) {
			wf(e.idents[0]);
		}
		return Continue; 
	}

	override Status visit(ref ir.Exp, ir.TokenExp fexp)
	{
		final switch (fexp.type) with (ir.TokenExp.Type) {
		case File:
			wf("__FILE__");
			break;
		case Line:
			wf("__LINE__");
			break;
		case PrettyFunction:
			wf("__PRETTY_FUNCTION__");
			break;
		case Function:
			wf("__FUNCTION__");
			break;
		case Location:
			wf("__LOCATION__");
			break;
		}
		return Continue;
	}

	override Status visit(ref ir.Exp, ir.StoreExp e)
	{
		if (e.idents.length > 1) for (size_t i = e.idents.length - 1; i > 0; --i) {
			wf(e.idents[i]);
			if (i > 1) {
				wf(".");
			}
		} else if (e.idents.length == 1) {
			wf(e.idents[0]);
		}
		return Continue;
	}

	/*
	 *
	 * Base stuff.
	 *
	 */

	override Status visit(ir.PrimitiveType type)
	{
		wStorageTypes(type);
		if (type.originalToken.type == TokenType.None) {
			wf(tokenToString(cast(TokenType)type.type));
		} else {
			wf(tokenToString(type.originalToken.type));
		}
		wAfterStorageTypes(type);
		return Continue;
	}

	override Status visit(ir.TypeReference tr)
	{
		wStorageTypes(tr);
		wf(tr.id);
		wAfterStorageTypes(tr);
		return Continue;
	}


	/*
	 *
	 * Helper functions.
	 *
	 */


protected:
	void internalPrintBlock(ir.BlockStatement bs)
	{
		foreach (statement; bs.statements) {
			accept(statement, this);
			if (statement.nodeType == ir.NodeType.Variable) {
				ln();
			}
		}
	}

	void wf(ir.QualifiedName qn)
	{
		if (qn.leadingDot)
			wf(".");
		if (qn.identifiers.length == 0) {
			return;
		}
		wf(qn.identifiers[0].value);

		foreach (id; qn.identifiers[1 .. $]) {
			wf(".");
			wf(id.value);
		}
	}

	void t()
	{
		for (int i; i < mIndent; ++i) {
			mSink(mIndentText);
		}
	}

	void twf(string[] strings...)
	{
		t();
		foreach (s; strings) {
			mSink(s);
		}
	}

	void twfln(string[] strings...)
	{
		foreach (s; strings) {
			twf(s);
			ln();
		}
	}

	void wf(string[] strings...)
	{
		foreach (s; strings) {
			mSink(s);
		}
	}

	void wf(int i)
	{
		string s = format("%s", i);
		mSink(s);
	}

	void wf(uint i)
	{
		string s = format("%s", i);
		mSink(s);
	}

	void wf(long l)
	{
		string s = format("%s", l);
		mSink(s);
	}

	void wf(ulong i)
	{
		string s = format("%s", i);
		mSink(s);
	}

	void wfln(string str){ wf(str); ln(); }

	void ln()
	{
		mSink("\n");
	}

	//! Print storage types.
	void wStorageTypes(ir.Type t)
	{
		if (t.isConst) {
			wf("const(");
		}
		if (t.isImmutable) {
			wf("immutable(");
		}
		if (t.isScope) {
			wf("scope (");
		}
	}

	void wAfterStorageTypes(ir.Type t)
	{
		if (t.isConst) {
			wf(")");
		}
		if (t.isImmutable) {
			wf(")");
		}
		if (t.isScope) {
			wf(")");
		}
	}


private:
	void sinkToStream(scope const(char)[] s)
	{
		version (D_Version2) { // Volt has better write methods.
			mStream.writef(`%s`, s);
		} else {
			mStream.write(s);
		}
	}

	version (D_Version2) { // Delegate deref
		void delegate(scope const(char)[]) sinkToStream()
		{
			return &sinkToStream;
		}
	}
}
