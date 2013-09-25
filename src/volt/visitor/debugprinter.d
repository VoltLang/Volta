// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.debugprinter;

import std.stdio : writefln, writef;
import std.stream : Stream, File, FileMode;
import std.cstream : dout;

import volt.token.token;

import volt.interfaces;

import ir = volt.ir.ir;
import volt.visitor.visitor;


void debugPrinter(ir.Module m)
{
	auto dp = new DebugPrinter();
	dp.transform(m);
	dp.close();
}

string getNodeAddressString(ir.Node node)
{
	return "0x" ~ to!string(*cast(size_t*)&node, 16);
}

class DebugMarker : Pass
{
protected:
	string mText;

public:
	this(string text) { mText = text; }

	override void close() {}

	override void transform(ir.Module m)
	{
		writefln("%s %s \"%s\"", mText, getNodeAddressString(m), m.name.toString);
	}
}

class DebugPrinter : Visitor, Pass, Backend
{
protected:
	string mFilename;
	Stream mStream;

	int mIndent;
	int mLastIndent;
	string mIndentText;

public:
	this(string indentText = null)
	{
		if (indentText is null) {
			version (Windows) {
				mIndentText = "  ";
			} else {
				mIndentText = "\t";
			}
		} else {
			mIndentText = indentText;
		}
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
		accept(m, this);
		mStream.writefln();
		mStream = null;
	}

	void transform(ref ir.Exp exp)
	in {
		assert(mStream is null);
		assert(mFilename is null);
	}
	body {
		assert(mStream is null);
		assert(mFilename is null);

		mStream = dout;
		acceptExp(exp, this);
		mStream.writefln();
		mStream = null;
	}


	/*
	 *
	 * Backend.
	 *
	 */


	TargetType[] supported()
	{
		return [TargetType.DebugPrinting];
	}

	void setTarget(string filename, TargetType type)
	in {
		assert(mStream is null);
		assert(mFilename is null);
		assert(type == TargetType.DebugPrinting);
	}
	body {
		if (type != TargetType.DebugPrinting)
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
	override Status enter(ir.Module n) { enterNode(n); return Continue; }
	override Status leave(ir.Module n) { leaveNode(n); return Continue; }
	override Status enter(ir.TopLevelBlock n) { enterNode(n); return Continue; }
	override Status leave(ir.TopLevelBlock n) { leaveNode(n); return Continue; }
	override Status enter(ir.Import n) { enterNode(n); return Continue; }
	override Status leave(ir.Import n) { leaveNode(n); return Continue; }
	override Status enter(ir.Unittest n) { enterNode(n); return Continue; }
	override Status leave(ir.Unittest n) { leaveNode(n); return Continue; }
	override Status enter(ir.Class n) { enterNode(n); visitNamed(n); return Continue; }
	override Status leave(ir.Class n) { leaveNode(n); return Continue; }
	override Status enter(ir._Interface n) { enterNode(n); return Continue; }
	override Status leave(ir._Interface n) { leaveNode(n); return Continue; }
	override Status enter(ir.Struct n) { enterNode(n); visitNamed(n); return Continue; }
	override Status leave(ir.Struct n) { leaveNode(n); return Continue; }
	override Status enter(ir.Union n) { enterNode(n); visitNamed(n); return Continue; }
	override Status leave(ir.Union n) { leaveNode(n); return Continue; }
	override Status enter(ir.Variable n) { enterNode(n); visitNamed(n); return Continue; }
	override Status leave(ir.Variable n) { leaveNode(n); return Continue; }
	override Status enter(ir.FunctionParam n) { enterNode(n); visitNamed(n); return Continue; }
	override Status leave(ir.FunctionParam n) { leaveNode(n); return Continue; }
	override Status enter(ir.Enum n) { enterNode(n); return Continue; }
	override Status leave(ir.Enum n) { leaveNode(n); return Continue; }
	override Status enter(ir.StaticAssert n) { enterNode(n); return Continue; }
	override Status leave(ir.StaticAssert n) { leaveNode(n); return Continue; }
	override Status enter(ir.Condition n) { enterNode(n); return Continue; }
	override Status leave(ir.Condition n) { leaveNode(n); return Continue; }
	override Status enter(ir.ConditionTopLevel n) { enterNode(n); return Continue; }
	override Status leave(ir.ConditionTopLevel n) { leaveNode(n); return Continue; }
	override Status leave(ir.MixinFunction n) { leaveNode(n); return Continue; }
	override Status leave(ir.MixinTemplate n) { leaveNode(n); return Continue; }
	override Status enter(ir.UserAttribute n) { enterNode(n); return Continue; }
	override Status leave(ir.UserAttribute n) { leaveNode(n); return Continue; }

	override Status visit(ir.EmptyTopLevel n) { visitNode(n); return Continue; }
	override Status visit(ir.QualifiedName n) { visitNode(n); return Continue; }


	override Status enter(ir.MixinFunction n)
	{
		enterNode(n);
		// Ok, to do this.	
		foreach (statement; n.raw.statements) {
			accept(statement, this);
		}
		return Continue;
	}

	override Status enter(ir.MixinTemplate n)
	{
		enterNode(n);
		// Ok, to do this.	
		foreach (node; n.raw.nodes) {
			accept(node, this);
		}
		return Continue;
	}

	override Status visit(ir.Identifier n)
	{
		ln();
		twf(["(", ir.nodeToString(n), " \"", n.value, "\")"]);
		mLastIndent = mIndent;
		return Continue;
	}

	/*
	 * Statement Nodes.
	 */
	override Status enter(ir.ExpStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.ExpStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.ReturnStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.ReturnStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.BlockStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.BlockStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.AsmStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.AsmStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.IfStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.IfStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.WhileStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.WhileStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.DoStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.DoStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.ForStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.ForStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.ForeachStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.ForeachStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.LabelStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.LabelStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.SwitchStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.SwitchStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.SwitchCase n) { enterNode(n); return Continue; }
	override Status leave(ir.SwitchCase n) { leaveNode(n); return Continue; }
	override Status enter(ir.GotoStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.GotoStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.WithStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.WithStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.SynchronizedStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.SynchronizedStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.TryStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.TryStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.ThrowStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.ThrowStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.ScopeStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.ScopeStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.PragmaStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.PragmaStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.ConditionStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.ConditionStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.MixinStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.MixinStatement n) { leaveNode(n); return Continue; }
	override Status enter(ir.AssertStatement n) { enterNode(n); return Continue; }
	override Status leave(ir.AssertStatement n) { leaveNode(n); return Continue; }
	
	override Status visit(ir.ContinueStatement n) { enterNode(n); return Continue; }
	override Status visit(ir.BreakStatement n) { enterNode(n); return Continue; }
	override Status visit(ir.EmptyStatement n) { visitNode(n); return Continue; }

	/*
	 * Declaration
	 */
	override Status enter(ir.PointerType n) { enterNode(n); return Continue; }
	override Status leave(ir.PointerType n) { leaveNode(n); return Continue; }
	override Status enter(ir.ArrayType n) { enterNode(n); return Continue; }
	override Status leave(ir.ArrayType n) { leaveNode(n); return Continue; }
	override Status enter(ir.StaticArrayType n) { enterNode(n); return Continue; }
	override Status leave(ir.StaticArrayType n) { leaveNode(n); return Continue; }
	override Status enter(ir.AAType n) { enterNode(n); return Continue; }
	override Status leave(ir.AAType n) { leaveNode(n); return Continue; }
	override Status enter(ir.FunctionType n) { enterNode(n); return Continue; }
	override Status leave(ir.FunctionType n) { leaveNode(n); return Continue; }
	override Status enter(ir.DelegateType n) { enterNode(n); return Continue; }
	override Status leave(ir.DelegateType n) { leaveNode(n); return Continue; }
	override Status enter(ir.Function n) { enterNode(n); visitNamed(n); return Continue; }
	override Status leave(ir.Function n) { leaveNode(n); return Continue; }
	override Status enter(ir.StorageType n) { enterNode(n); return Continue; }
	override Status leave(ir.StorageType n) { leaveNode(n); return Continue; }
	override Status enter(ir.Attribute n) { enterNode(n); return Continue; }
	override Status leave(ir.Attribute n) { leaveNode(n); return Continue; }
	override Status enter(ir.Alias n) { enterNode(n); return Continue; }
	override Status leave(ir.Alias n) { leaveNode(n); return Continue; }
	override Status enter(ir.TypeOf n) { enterNode(n); return Continue; }
	override Status leave(ir.TypeOf n) { leaveNode(n); return Continue; }
	override Status enter(ir.EnumDeclaration n) { enterNode(n); return Continue; }
	override Status leave(ir.EnumDeclaration n) { leaveNode(n); return Continue; }

	override Status visit(ir.NullType n) { visitNode(n); return Continue; }
	override Status visit(ir.PrimitiveType n) { visitNode(n); return Continue; }
	override Status visit(ir.TypeReference n) { visitRef(n, n.type); return Continue; }


	/*
	 * Expression Nodes.
	 */
	override Status enter(ref ir.Exp, ir.Postfix n) { enterNode(n, to!string(n.op)); return Continue; }
	override Status leave(ref ir.Exp, ir.Postfix n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.Unary n) { enterNode(n, to!string(n.op)); return Continue; }
	override Status leave(ref ir.Exp, ir.Unary n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.BinOp n) { enterNode(n, to!string(n.op)); return Continue; }
	override Status leave(ref ir.Exp, ir.BinOp n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.Ternary n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.Ternary n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.ArrayLiteral n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.ArrayLiteral n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.AssocArray n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.AssocArray n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.Assert n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.Assert n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.StringImport n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.StringImport n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.Typeid n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.Typeid n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.IsExp n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.IsExp n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.FunctionLiteral n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.FunctionLiteral n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.StructLiteral n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.StructLiteral n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.ClassLiteral n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.ClassLiteral n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.Constant n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.Constant n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.TypeExp n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.TypeExp n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.TemplateInstanceExp n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.TemplateInstanceExp n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.StatementExp n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.StatementExp n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.VaArgExp n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.VaArgExp n) { leaveNode(n); return Continue; }


	override Status visit(ref ir.Exp, ir.ExpReference n) { visitRef(n, n.decl); return Continue; }
	override Status visit(ref ir.Exp, ir.TraitsExp n) { visitNode(n); return Continue; }
	override Status visit(ref ir.Exp, ir.TokenExp n) { visitNode(n); return Continue; }

	override Status debugVisitNode(ir.Node n) { return Continue; }

	override Status visit(ref ir.Exp, ir.IdentifierExp n)
	{
		ln();
		twf(["(", ir.nodeToString(n), " \"", n.value, "\")"]);
		mLastIndent = mIndent;
		return Continue;
	}


protected:
	void enterNode(ir.Node node)
	{
		if (mIndent != 0)
			ln();
		twf(["(", ir.nodeToString(node), " ", getNodeAddressString(node)]);
		mLastIndent = mIndent++;
	}

	void enterNode(ir.Node node, string extra)
	{
		if (mIndent != 0)
			ln();
		twf(["(", ir.nodeToString(node), " ", extra, " ", getNodeAddressString(node)]);
		mLastIndent = mIndent++;
	}

	void leaveNode(ir.Node node)
	{
		mIndent--;
		if (mIndent == mLastIndent) {
			wf(")");
		} else {
			ln();
			twf(")");
		}
	}

	void visitRef(ir.Node node, ir.Node r)
	{
		enterNode(node);

		ln();
		if (r !is null) {
			twf(["-> ", ir.nodeToString(r), " ", getNodeAddressString(r)]);
			visitNamed(r);
		} else {
			twf("-> null");
		}
		mLastIndent = mIndent;

		leaveNode(node);
	}

	void visitNamed(ir.Node n)
	{
		switch (n.nodeType) with (ir.NodeType) {
		case Function:
			auto asFn = cast(ir.Function)n;
			return visitNames(asFn.name, asFn.mangledName);
		case Variable:
			auto asVar = cast(ir.Variable)n;
			return visitNames(asVar.name, asVar.mangledName);
		case FunctionParam:
			auto asFP = cast(ir.FunctionParam)n;
			return visitName(asFP.name);
		case Class:
			auto asClass = cast(ir.Class)n;
			return visitName(asClass.name);
		case Struct:
			auto asStruct = cast(ir.Struct)n;
			return visitName(asStruct.name);
		default:
		}
	}

	void visitNames(string name, string mangledName)
	{
		wf(" \"", name, "\"");
		if (mangledName !is null) {
			wf(" \"", mangledName, "\"");
		}
	}

	void visitName(string name)
	{
		wf(" \"", name, "\"");
	}

	void visitNode(ir.Node node)
	{
		ln();
		twf(["(", ir.nodeToString(node), " ", getNodeAddressString(node), ")"]);
		mLastIndent = mIndent;
	}

	void twf(string[] strings...)
	{
		for(int i; i < mIndent; i++)
			mStream.writef(mIndentText);
		foreach (s; strings) {
			mStream.writef(s);
		}
	}

	void twfln(string[] strings...)
	{
		foreach (s; strings) {
			twf(s);
			mStream.writefln();
		}
	}

	void wf(string[] strings...)
	{
		foreach (s; strings) {
			mStream.writef(s);
		}
	}

	void wf(size_t i) { mStream.writef("%s", i); }
	void wfln(string str) { wf(str); mStream.writefln(); }
	void ln() { mStream.writefln(); }
}
