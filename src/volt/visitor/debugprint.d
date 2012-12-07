// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.debugprint;

import std.stdio : writefln, writef;
import std.stream : Stream, File, FileMode;
import std.cstream : dout;

import volt.token.token;

import volt.exceptions;
import volt.interfaces;

import ir = volt.ir.ir;
import volt.visitor.visitor;


void debugPrintVisitor(ir.Module m)
{
	auto dpv = new DebugPrintVisitor();
	accept(m, dpv);
	dpv.close();
}

class DebugPrintVisitor : Visitor, Pass, Backend
{
protected:
	string mFilename;
	Stream mStream;

	int mIndent;
	int mLastIndent;
	string mIndentText;
	string mStartText;

public:
	this(string startText = null, string indentText = "\t")
	{
		mIndentText = indentText;
		mStartText = startText;
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
		if (mStartText != null)
			mStream.writefln(mStartText);
		accept(m, this);
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
	override Status enter(ir.Import n) { enterNode(n); return Continue; }
	override Status leave(ir.Import n) { leaveNode(n); return Continue; }
	override Status enter(ir.Unittest n) { enterNode(n); return Continue; }
	override Status leave(ir.Unittest n) { leaveNode(n); return Continue; }
	override Status enter(ir.Class n) { enterNode(n); return Continue; }
	override Status leave(ir.Class n) { leaveNode(n); return Continue; }
	override Status enter(ir._Interface n) { enterNode(n); return Continue; }
	override Status leave(ir._Interface n) { leaveNode(n); return Continue; }
	override Status enter(ir.Struct n) { enterNode(n); return Continue; }
	override Status leave(ir.Struct n) { leaveNode(n); return Continue; }
	override Status enter(ir.Variable n) { enterNode(n); return Continue; }
	override Status leave(ir.Variable n) { leaveNode(n); return Continue; }
	override Status enter(ir.Enum n) { enterNode(n); return Continue; }
	override Status leave(ir.Enum n) { leaveNode(n); return Continue; }
	override Status enter(ir.StaticAssert n) { enterNode(n); return Continue; }
	override Status leave(ir.StaticAssert n) { leaveNode(n); return Continue; }
	override Status enter(ir.Condition n) { enterNode(n); return Continue; }
	override Status leave(ir.Condition n) { leaveNode(n); return Continue; }
	override Status enter(ir.ConditionTopLevel n) { enterNode(n); return Continue; }
	override Status leave(ir.ConditionTopLevel n) { leaveNode(n); return Continue; }

	override Status visit(ir.EmptyTopLevel n) { visitNode(n); return Continue; }
	override Status visit(ir.QualifiedName n) { visitNode(n); return Continue; }
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
	override Status enter(ir.Function n) { enterNode(n); return Continue; }
	override Status leave(ir.Function n) { leaveNode(n); return Continue; }
	override Status enter(ir.StorageType n) { enterNode(n); return Continue; }
	override Status leave(ir.StorageType n) { leaveNode(n); return Continue; }
	override Status enter(ir.Attribute n) { enterNode(n); return Continue; }
	override Status leave(ir.Attribute n) { leaveNode(n); return Continue; }

	override Status visit(ir.PrimitiveType n) { visitNode(n); return Continue; }
	override Status visit(ir.TypeReference n) { visitRef(n, n.type); return Continue; }
	override Status visit(ir.Alias n) { visitNode(n); return Continue; }

	/*
	 * Expression Nodes.
	 */
	override Status enter(ir.Postfix n) { enterNode(n); return Continue; }
	override Status leave(ir.Postfix n) { leaveNode(n); return Continue; }
	override Status enter(ir.Unary n) { enterNode(n); return Continue; }
	override Status leave(ir.Unary n) { leaveNode(n); return Continue; }
	override Status enter(ir.BinOp n) { enterNode(n); return Continue; }
	override Status leave(ir.BinOp n) { leaveNode(n); return Continue; }
	override Status enter(ir.Ternary n) { enterNode(n); return Continue; }
	override Status leave(ir.Ternary n) { leaveNode(n); return Continue; }
	override Status enter(ir.Array n) { enterNode(n); return Continue; }
	override Status leave(ir.Array n) { leaveNode(n); return Continue; }
	override Status enter(ir.AssocArray n) { enterNode(n); return Continue; }
	override Status leave(ir.AssocArray n) { leaveNode(n); return Continue; }
	override Status enter(ir.Assert n) { enterNode(n); return Continue; }
	override Status leave(ir.Assert n) { leaveNode(n); return Continue; }
	override Status enter(ir.StringImport n) { enterNode(n); return Continue; }
	override Status leave(ir.StringImport n) { leaveNode(n); return Continue; }
	override Status enter(ir.Typeid n) { enterNode(n); return Continue; }
	override Status leave(ir.Typeid n) { leaveNode(n); return Continue; }
	override Status enter(ir.IsExp n) { enterNode(n); return Continue; }
	override Status leave(ir.IsExp n) { leaveNode(n); return Continue; }
	override Status enter(ir.FunctionLiteral n) { enterNode(n); return Continue; }
	override Status leave(ir.FunctionLiteral n) { leaveNode(n); return Continue; }

	override Status visit(ir.ExpReference n) { visitRef(n, n.decl); return Continue; }
	override Status visit(ir.Constant n) { visitNode(n); return Continue; }

	override Status debugVisitNode(ir.Node n) { return Continue; }

	override Status visit(ir.IdentifierExp n)
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
		twf(["(", ir.nodeToString(node), " 0x", to!string(*cast(size_t*)&node)]);
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
			twf(["-> ", ir.nodeToString(r), " 0x", to!string(*cast(size_t*)&r)]);
		} else {
			twf("-> null");
		}
		mLastIndent = mIndent;

		leaveNode(node);
	}

	void visitNode(ir.Node node)
	{
		ln();
		twf(["(", ir.nodeToString(node), " 0x", to!string(*cast(size_t*)&node), ")"]);
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
