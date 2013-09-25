// Copyright © 2012, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.prettyprinter;

import std.stream : Stream, File, FileMode;
import std.cstream : dout;
import std.string : format;

import volt.token.token;

import volt.errors;
import volt.interfaces;

import ir = volt.ir.ir;
import volt.visitor.visitor;


void prettyPrinter(ir.Module m)
{
	auto pp = new PrettyPrinter();
	pp.transform(m);
	pp.close();
}

class PrettyPrinter : Visitor, Pass, Backend
{
protected:
	string mFilename;
	Stream mStream;
	void delegate(string) mSink;

	int mIndent;
	string mIndentText;

public:
	this(string indentText = "\t", void delegate(string) sink = null)
	{
		mIndentText = indentText;
		mSink = sink;
	}

	void close()
	{
		mFilename = null;
		assert(mStream is null);
		assert(mFilename is null);
	}


	/*
	 *
	 * Pass functions.
	 *
	 */


	void transform(ir.Module m)
	in {
		assert(mStream is null);
		assert(mFilename is null);
	}
	body {
		assert(mStream is null);
		assert(mFilename is null);

		mStream = dout;
		void sink(string s)
		{
			mStream.writef("%s", s);
		}
		bool sinkWasNull;
		if (mSink is null) {
			mSink = &sink;
			sinkWasNull = true;
		}

		accept(m, this);
		mSink("\n");
		mStream = null;
		if (sinkWasNull) {
			mSink = null;
		}
	}

	void transform(ir.Type t)
	{
		accept(t, this);
	}


	/*
	 *
	 * Backend.
	 *
	 */


	TargetType[] supported()
	{
		return [TargetType.VoltCode];
	}

	void setTarget(string filename, TargetType type)
	in {
		assert(mStream is null);
		assert(mFilename is null);
		assert(type == TargetType.VoltCode);
	}
	body {
		if (type != TargetType.VoltCode)
			throw new Exception("Unsupported target type");

		mFilename = filename;
	}

	void compile(ir.Module m)
	in {
		assert(mStream is null);
		assert(mFilename !is null);
	}
	body {
		scope(exit)
			mFilename = null;

		mStream = new File(mFilename, FileMode.OutNew);
		scope(exit) {
			mStream.flush();
			mStream.close();
			mStream = null;
		}

		accept(m, this);
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
		accept(i.name, this);
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
		ln();
		twf("class ", c.name);
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
		ln();
		twf("interface ", i.name);
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
		ln();
		twf("struct ");
		wf(s.name);
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
		ln();
		twf("union ");
		wf(u.name);
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
			acceptExp(d.assign, this);
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
				acceptExp(member.assign, this);
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
		case Package: twf("package"); break;
		case Override: twf("override"); break;
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
			accept(attr.arguments[0], this);
			wf(")");
			break;
		case UserAttribute:
			twf("@");
			wf(attr.userAttributeName);
			wf("(");
			foreach (i, arg; attr.arguments) {
				accept(arg, this);
				if (i < attr.arguments.length - 1) {
					wf(", ");
				}
			}
			wf(")");
			break;
		}

		wfln(" {");
		mIndent++;
		foreach (member; attr.members.nodes) {
			accept(member, this);
		}
		mIndent--;
		twfln("}");

		return ContinueParent;
	}

	override Status leave(ir.Attribute attr)
	{
		assert(false);
	}

	override Status enter(ir.StaticAssert sa)
	{
		ln();
		twf("static assert(");
		acceptExp(sa.exp, this);
		if (sa.message !is null) {
			wf(", ");
			accept(sa.message, this);
		}
		wfln(");");
		return ContinueParent;
	}

	override Status leave(ir.StaticAssert sa)
	{
		assert(false);
	}

	override Status visit(ir.EmptyTopLevel empty)
	{
		twfln("\n;");
		return Continue;
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
		case Version:
			twf("version (");
			break;
		case Debug:
			twf("debug (");
			break;
		case StaticIf:
			twf("static if (");
			break;
		}
		acceptExp(c.exp, this);
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
		acceptExp(e.exp, this);
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
		acceptExp(i.exp, this);
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
		acceptExp(w.condition, this);
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
		acceptExp(d.condition, this);
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
			acceptExp(fes.beginIntegerRange, this);
			wf(" .. ");
			acceptExp(fes.endIntegerRange, this);
		} else {
			acceptExp(fes.aggregate, this);
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
				acceptExp(i, this);
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
					acceptExp(d.assign, this);
				}
				if (i < f.initVars.length - 1) {
					wf(", ");
				}
			}
		}
		wf(";");
		if (f.test !is null) {
			wf(" ");
			acceptExp(f.test, this);
		}
		wf(";");
		if (f.increments.length > 0) {
			wf(" ");
			foreach (i, ref increment; f.increments) {
				acceptExp(increment, this);
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
		acceptExp(ss.condition, this);
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
				acceptExp(sc.firstExp, this);
				wfln(":");
			} else if (sc.firstExp !is null && sc.secondExp !is null) {
				acceptExp(sc.firstExp, this);
				wf(": .. case ");
				acceptExp(sc.secondExp, this);
				wfln(":");
			} else if (sc.exps.length > 0) {
				foreach (i, exp; sc.exps) {
					acceptExp(exp, this);
					if (i < sc.exps.length - 1) {
						wf(", ");
					}
				}
				wfln(":");
			} else {
				throw panic(sc.location, "unknown case type passed to PrintVisitor.");
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
		wf(ls.label ~ ":");
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
				acceptExp(gs.exp, this);
			}
		} else {
			throw panic(gs.location, "malformed goto statement made it to PrintVisitor.");
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
		acceptExp(ws.exp, this);
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
			acceptExp(ss.exp, this);
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

		if (ts.catchAll !is null) {
			wfln("catch {");
			mIndent++;
			internalPrintBlock(ts.catchAll);
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
		acceptExp(ts.exp, this);
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
		final switch (ss.kind) with (ir.ScopeStatement.Kind) {
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
				acceptExp(arg, this);
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

	override Status visit(ir.EmptyStatement es)
	{
		twfln(";");
		return Continue;
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
		acceptExp(as.condition, this);
		if (as.message !is null) {
			wf(", ");
			acceptExp(as.message, this);
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
			
			acceptExp(ms.stringExp, this);
			
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
	
	override Status enter(ir.UserAttribute ui)
	{
		twf("@interface ");
		wf(ui.name);
		wfln(" {");
		mIndent++;
		return Continue;
	}

	override Status leave(ir.UserAttribute ui)
	{
		mIndent--;
		twfln("}");
		return Continue;
	}

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
			acceptExp(ed.assign, this);
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
		accept(pointer.base, this);
		wf("*");
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
		accept(array.base, this);
		wf("[]");
		return ContinueParent;
	}

	override Status leave(ir.ArrayType array)
	{
		return Continue;
	}

	override Status enter(ir.StaticArrayType array)
	{
		accept(array.base, this);
		wf("[");
		wf(array.length);
		wf("]");
		return ContinueParent;
	}

	override Status leave(ir.StaticArrayType array)
	{
		return Continue;
	}

	override Status enter(ir.AAType array)
	{
		accept(array.value, this);
		wf("[");
		accept(array.key, this);
		wf("]");
		return ContinueParent;
	}

	override Status enter(ir.FunctionType fn)
	{
		accept(fn.ret, this);
		wf(" function(");
		foreach (i, param; fn.params) {
			accept(param, this);
			if (i < fn.params.length - 1) {
				wf(", ");
			}
		}
		if (fn.hasVarArgs) {
			wf(", ...");
		}
		wf(")");
		return ContinueParent;
	}

	override Status leave(ir.FunctionType fn)
	{
		return Continue;
	}

	override Status enter(ir.DelegateType fn)
	{
		accept(fn.ret, this);
		wf(" delegate(");
		foreach (i, param; fn.params) {
			accept(param, this);
			if (i < fn.params.length - 1) {
				wf(", ");
			}
		}
		if (fn.hasVarArgs) {
			wf(", ...");
		}
		wf(")");
		return ContinueParent;
	}

	override Status leave(ir.DelegateType fn)
	{
		return Continue;
	}

	override Status leave(ir.AAType array)
	{
		return Continue;
	}
	
	override Status enter(ir.Function fn)
	{
		ln();
		twf("");

		final switch(fn.kind) with (ir.Function.Kind) {
		case LocalMember:
			wf("local ");
			goto case Member;
		case GlobalMember:
			wf("local ");
			goto case Member;
		case Invalid:
		case Function:
		case Member:
			accept(fn.type.ret, this);
			wf(" ");
			wf(fn.mangledName);
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

		foreach (i, param; fn.params) {
			accept(param.type, this);
			if (param.name.length > 0) {
				wf(" ");
				wf(param.name);
			}
			if (i < fn.type.params.length - 1) {
				wf(", ");
			}
		}
		if (fn.type.hasVarArgs) {
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

		if (fn.inContract !is null) {
			ln();
			twfln("in {");
			printNodes(fn.inContract.statements);
			ln();
			twfln("}");
		}

		if (fn.outContract !is null) {
			if (fn.outParameter.length > 0) {
				twfln("out (" ~ fn.outParameter ~ ") {");
			} else {
				twfln("out {");
			}
			printNodes(fn.outContract.statements);
			ln();
			twfln("}");
		}

		if (fn._body !is null) {
			if (fn.inContract is null || fn.outContract is null) {
				twfln("body {");
			} else {
				ln();
				twfln("{");
			}

			printNodes(fn._body.statements);

			ln();
			twfln("}");
		} else {
			wfln(";");
		}

		return ContinueParent;
	}

	override Status leave(ir.Function fn)
	{
		return Continue;
	}

	override Status enter(ir.StorageType type)
	{
		final switch (type.type) with (ir.StorageType.Kind) {
		case Auto: wf("auto("); break;
		case Const: wf("const("); break;
		case Immutable: wf("immutable("); break;
		case Scope: wf("scope("); break;
		case Ref: wf("ref("); break;
		case Out: wf("out("); break;
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

	override Status enter(ir.Alias a)
	{
		ln();
		twf("alias ");
		wf(a.name);
		wf(" = ");
		if (a.type !is null)
			accept(a.type, this);
		else if (a.id !is null)
			accept(a.id, this);
		else
			wf("null");
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
		acceptExp(typeOf.exp, this);
		wf(")");
		return ContinueParent;
	}

	override Status leave(ir.TypeOf typeOf)
	{
		assert(false);
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
			case Bool: wf(to!string(constant._bool)); break;
			case Uint: wf(constant._uint); break;
			case Int: wf(constant._int); break;
			case Long: wf(constant._long); break;
			case Ulong: wf(constant._ulong); break;
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
		foreach (i, exp; array.values) {
			acceptExp(exp, this);
			if (i < array.values.length - 1) {
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
			acceptExp(pair.key, this);
			wf(":");
			acceptExp(pair.value, this);
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
		acceptExp(_assert.condition, this);
		if (_assert.message !is null) {
			wf(", ");
			acceptExp(_assert.message, this);
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
		acceptExp(strimport.filename, this);
		wf(")");
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.StringImport strimport)
	{
		return Continue;
	}

	override Status enter(ref ir.Exp, ir.Ternary ternary)
	{
		acceptExp(ternary.condition, this);
		wf(" ? ");
		acceptExp(ternary.ifTrue, this);
		wf(" : ");
		acceptExp(ternary.ifFalse, this);
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.Ternary ternary)
	{
		return Continue;
	}

	override Status enter(ref ir.Exp, ir.BinOp binop)
	{
		wf("(");

		acceptExp(binop.left, this);

		switch (binop.op) {
		case ir.BinOp.Op.Assign: wf(" = "); break;
		case ir.BinOp.Op.AddAssign: wf(" += "); break;
		case ir.BinOp.Op.SubAssign: wf(" -= "); break;
		case ir.BinOp.Op.MulAssign: wf(" *= "); break;
		case ir.BinOp.Op.DivAssign: wf(" /= "); break;
		case ir.BinOp.Op.ModAssign: wf(" %= "); break;
		case ir.BinOp.Op.AndAssign: wf(" &= "); break;
		case ir.BinOp.Op.OrAssign: wf(" |= "); break;
		case ir.BinOp.Op.XorAssign: wf(" ^= "); break;
		case ir.BinOp.Op.CatAssign: wf(" ~= "); break;
		case ir.BinOp.Op.LSAssign: wf(" <<= "); break;
		case ir.BinOp.Op.SRSAssign: wf(" >>= "); break;
		case ir.BinOp.Op.RSAssign: wf(" >>>= "); break;
		case ir.BinOp.Op.PowAssign: wf(" ^^= "); break;
		case ir.BinOp.Op.OrOr: wf(" || "); break;
		case ir.BinOp.Op.AndAnd: wf(" && "); break;
		case ir.BinOp.Op.Or: wf(" | "); break;
		case ir.BinOp.Op.Xor: wf(" ^ "); break;
		case ir.BinOp.Op.And: wf(" & "); break;
		case ir.BinOp.Op.Equal: wf(" == "); break;
		case ir.BinOp.Op.NotEqual: wf(" != "); break;
		case ir.BinOp.Op.Is: wf(" is "); break;
		case ir.BinOp.Op.NotIs: wf(" !is "); break;
		case ir.BinOp.Op.Less: wf(" < "); break;
		case ir.BinOp.Op.LessEqual: wf(" <= "); break;
		case ir.BinOp.Op.GreaterEqual: wf(" >= "); break;
		case ir.BinOp.Op.Greater: wf(" > "); break;
		case ir.BinOp.Op.In: wf(" in "); break;
		case ir.BinOp.Op.NotIn: wf(" !in "); break;
		case ir.BinOp.Op.LS: wf(" << "); break;
		case ir.BinOp.Op.SRS: wf(" >> "); break;
		case ir.BinOp.Op.RS: wf(" >>> "); break;
		case ir.BinOp.Op.Add: wf(" + "); break;
		case ir.BinOp.Op.Sub: wf(" - "); break;
		case ir.BinOp.Op.Cat: wf(" ~ "); break;
		case ir.BinOp.Op.Mul: wf(" * "); break;
		case ir.BinOp.Op.Div: wf(" / "); break;
		case ir.BinOp.Op.Mod: wf(" % "); break;
		case ir.BinOp.Op.Pow: wf(" ^^ "); break;
		default: assert(false);
		}

		acceptExp(binop.right, this);

		wf(")");

		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.BinOp binop)
	{
		return Continue;
	}

	override Status enter(ref ir.Exp, ir.Unary unary)
	{
		switch (unary.op) {
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
					acceptExp(arg, this);
					if (i < unary.argumentList.length - 1) {
						wf(", ");
					}
					wf(")");
				}
			}
			break;
		default: assert(false);
		}

		if (unary.value !is null) {
			acceptExp(unary.value, this);
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
			acceptExp(postfix.child, this);
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
				acceptExp(arg, this);
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
				acceptExp(postfix.arguments[0], this);
				break;
			case 2:
				acceptExp(postfix.arguments[0], this);
				wf("..");
				acceptExp(postfix.arguments[1], this);
				break;
			default:
				throw panic(postfix.location, "bad slice.");
			}
			wf("]");
			break;
		case ir.Postfix.Op.Call:
			wf("(");
			foreach (i, arg; postfix.arguments) {
				acceptExp(arg, this);
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
			throw panic(postfix.location, "tried to print bad postfix expression.");
		}

		return ContinueParent;
	}

	override Status enter(ref ir.Exp, ir.Typeid ti)
	{
		wf("typeid(");
		if (ti.exp !is null) {
			acceptExp(ti.exp, this);
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
		if (isExp.identifier.length > 0) {
			wf(" ", isExp.identifier);
		}
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
			acceptExp(functionLiteral.lambdaExp, this);
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
			acceptExp(exp, this);
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

	override Status enter(ref ir.Exp, ir.ClassLiteral cliteral)
	{
		wf("{ ");
		foreach (i, ref exp; cliteral.exps) {
			acceptExp(exp, this);
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

	override Status enter(ref ir.Exp, ir.TemplateInstanceExp texp)
	{
		wf(texp.name, "!(");
		foreach (i, type; texp.types) {
			accept(type, this);
			if (i < texp.types.length - 1) {
				wf(", ");
			} else {
				wf(")");
			}
		}
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.TemplateInstanceExp texp)
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
			acceptExp(statExp.exp, this);
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
		acceptExp(vaexp.arg, this);
		wf(")");
		return ContinueParent;
	}

	override Status leave(ref ir.Exp, ir.VaArgExp vaexp)
	{
		assert(false);
	}

	override Status visit(ref ir.Exp, ir.ExpReference e)
	{ 
		if (e.idents.length > 1) for (int i = cast(int)e.idents.length - 1; i > 0; --i) {
			wf(e.idents[i]);
			if (i > 1) {
				wf(".");
			}
		} else if (e.idents.length == 1) {
			wf(e.idents[0]);
		}
		return Continue; 
	}

	override Status visit(ref ir.Exp, ir.TraitsExp texp)
	{
		assert(texp.op == ir.TraitsExp.Op.GetAttribute);
		wf("__traits(getAttribute, ");
		accept(texp.target, this);
		wf(", ");
		accept(texp.qname, this);
		wf(")");
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
		}
		return Continue;
	}

	/*
	 *
	 * Base stuff.
	 *
	 */

	override Status debugVisitNode(ir.Node n)
	{
		return Continue;
	}

	override Status visit(ir.PrimitiveType type)
	{
		wf(tokenToString[type.type]);
		return Continue;
	}

	override Status visit(ir.TypeReference tr)
	{
		wf(tr.id);
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
		wf(qn.identifiers[0].value);

		foreach(id; qn.identifiers[1 .. $]) {
			wf(".");
			wf(id.value);
		}
	}

	void twf(string[] strings...)
	{
		for (int i; i < mIndent; i++) {
			mSink(mIndentText);
		}
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

	void wf(long l)
	{
		string s = format("%s", l);
		mSink(s);
	}

	void wf(size_t i)
	{
		string s = format("%s", i);
		mSink(s);
	}

	void wfln(string str){ wf(str); ln(); }

	void ln()
	{
		mSink("\n");
	}
}
