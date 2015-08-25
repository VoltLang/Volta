// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.debugprinter;


import watt.io.streams : OutputStream;
import watt.io.std : writefln, writef, output;
import watt.conv : toString;

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

void debugPrintNode(ir.Node n)
{
	auto dp = new DebugPrinter();
	dp.transformNode(n);
	dp.close();
}

class DebugMarker : Pass
{
protected:
	string mText;

public:
	this(string text) { mText = text; }

	override void transform(ir.Module m)
	{
		writefln("%s %s \"%s\"", mText, ir.getNodeAddressString(m), m.name.toString);
	}

	override void close() {}
}

class DebugPrinter : Visitor, Pass/*, Backend */
{
protected:
	string mFilename;
	OutputStream mStream;
	void delegate(string) mSink;

	int mIndent;
	int mLastIndent;
	string mIndentText;

public:
	this(string indentText = " ", void delegate(string) sink = null)
	{
		mIndentText = indentText;
		mSink = sink;
	}


	/*
	 *
	 * Pass functions.
	 *
	 */

	override void close()
	{
		mFilename = null;
		assert(mStream is null);
		assert(mFilename is null);
	}

	override void transform(ir.Module m)
	in {
		assert(mStream is null);
		assert(mFilename is null);
	}
	body {
		assert(mStream is null);
		assert(mFilename is null);

		mStream = output;
		void sink(string s)
		{
			mStream.writef("%s", s);
		}
		bool sinkWasNull;
		if (mSink is null) {
			version (Volt) {
				mSink = cast(typeof(mSink))sink;
			} else {
				mSink = &sink;
			}
			sinkWasNull = true;
		}

		accept(m, this);
		mSink("\n");
		mStream = null;
		if (sinkWasNull) {
			mSink = null;
		}
	}

	void transformExp(ref ir.Exp exp)
	in {
		assert(mStream is null);
		assert(mFilename is null);
	}
	body {
		assert(mStream is null);
		assert(mFilename is null);

		mStream = output;
		void sink(string s)
		{
			mStream.writef("%s", s);
		}
		bool sinkWasNull;
		if (mSink is null) {
			version (Volt) {
				mSink = cast(typeof(mSink))sink;
			} else {
				mSink = &sink;
			}
			sinkWasNull = true;
		}

		acceptExp(exp, this);
		mSink("\n");
		mStream = null;
		if (sinkWasNull) {
			mSink = null;
		}
	}

	void transformNode(ir.Node n)
	in {
		assert(mStream is null);
		assert(mFilename is null);
	}
	body {
		assert(mStream is null);
		assert(mFilename is null);

		mStream = output;
		void sink(string s)
		{
			mStream.writef("%s", s);
		}
		bool sinkWasNull;
		if (mSink is null) {
			version (Volt) {
				mSink = cast(typeof(mSink))sink;
			} else {
				mSink = &sink;
			}
			sinkWasNull = true;
		}

		auto exp = cast(ir.Exp)n;
		if (exp is null) {
			accept(n, this);
		} else {
			acceptExp(exp, this);
		}
		mSink("\n");
		mStream = null;
		if (sinkWasNull) {
			mSink = null;
		}
	}


	/*
	 *
	 * Root
	 *
	 */
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

	override Status visit(ir.QualifiedName n) { visitNode(n); return Continue; }


	override Status enter(ir.Module n)
	{
		ln();
		mLastIndent = mIndent;
		if (mIndent != 0)
			ln();
		twf(["(", ir.nodeToString(n), " \"", n.name.toString(), "\" ", ir.getNodeAddressString(n)]);
		mLastIndent = mIndent++;
		return Continue;
	}

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
	override Status enter(ref ir.Exp, ir.Postfix n) { enterNode(n, .toString(n.op)); return Continue; }
	override Status leave(ref ir.Exp, ir.Postfix n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.Unary n) { enterNode(n, .toString(n.op)); return Continue; }
	override Status leave(ref ir.Exp, ir.Unary n) { leaveNode(n); return Continue; }
	override Status enter(ref ir.Exp, ir.BinOp n) { enterNode(n, .toString(n.op)); return Continue; }
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
	override Status enter(ref ir.Exp, ir.UnionLiteral n) { enterNode(n); return Continue; }
	override Status leave(ref ir.Exp, ir.UnionLiteral n) { leaveNode(n); return Continue; }
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
		twf(["(", node.docComment, ir.nodeToString(node), " ", ir.getNodeAddressString(node)]);
		printTypeFields(node);
		mLastIndent = mIndent++;
	}

	void enterNode(ir.Node node, string extra)
	{
		if (mIndent != 0)
			ln();

		twf(["(", node.docComment, ir.nodeToString(node), " ", extra, " ", ir.getNodeAddressString(node)]);
		printTypeFields(node);
		mLastIndent = mIndent++;
	}

	void printTypeFields(ir.Node node)
	{
		auto t = cast(ir.Type)node;
		if (t is null) {
			return;
		}

		wf("\n");
		twf("  .mangledName \"", t.mangledName, "\"\n");
		twf("  .glossedName \"", t.glossedName, "\"\n");
		twf("  .isConst ", .toString(t.isConst), "\n");
		twf("  .isScope ", .toString(t.isScope), "\n");
		twf("  .isImmutable ", .toString(t.isImmutable));
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
			twf(["-> ", ir.nodeToString(r), " ", ir.getNodeAddressString(r)]);
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
		twf("(", node.docComment, ir.nodeToString(node), " ", ir.getNodeAddressString(node));
		printTypeFields(node);
		wf(")");
		mLastIndent = mIndent;
	}

	void twf(string[] strings...)
	{
		for(int i; i < mIndent; i++)
			mSink(mIndentText);
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

	void wf(size_t i)
	{
		string s = format("%s", i);
		mSink(s);
	}

	void wfln(string str) { wf(str); ln(); }
	void ln() { mSink("\n"); }
}
