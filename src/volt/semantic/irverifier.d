/*#D*/
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.irverifier;

import watt.text.format : format;

import ir = volta.ir;

import volt.errors;
import volt.interfaces;
import volta.ir.location;
import volta.visitor.visitor;
import volta.visitor.scopemanager;

import volt.semantic.classify;


/*!
 * This verifier is design to catch faulty IR (from the view
 * of the backends) that the LanguagePass generate.
 *
 * Such as implicit casts or parser nodes that should have
 * been cleaned or uninitialized fields (such as magnedName).
 *
 * @ingroup passes passLang passSem
 */
class IrVerifier : ScopeManager, Pass
{
private:
	int[size_t] mNodes;
	int mCount;

public:
	this(ErrorSink errSink)
	{
		super(errSink);
	}

public:
	override void transform(ir.Module m)
	{
		mNodes = null;
		mCount = 0;
		accept(m, this);
	}

	override void close()
	{
	}


public:
	override Status enter(ir.Variable v)
	{
		checkNode(v);
		if (v.storage != ir.Variable.Storage.Invalid) {
			return Continue;
		}
		auto str = format("%s invalid variable found in IR",
		                  ir.getNodeAddressString(v));
		throw panic(v, str);
	}

	override Status enter(ir.StorageType st)
	{
		checkNode(st);
		throw panic(st, "storage type found in IR.");
	}

	override Status visit(ir.TypeReference tr)
	{
		checkNode(tr);
		if (tr.type is null) {
			throw panic(tr, "TypeReference.type is null");
		}
		if (tr.type.nodeType != ir.NodeType.Enum &&
		    tr.type.nodeType != ir.NodeType.Class &&
		    tr.type.nodeType != ir.NodeType.Union &&
		    tr.type.nodeType != ir.NodeType.Struct &&
		    tr.type.nodeType != ir.NodeType.Interface) {
			throw panic(tr, "TypeReference.type is points to invalid class");
		}
		return Continue;
	}

	override Status enter(ir.FunctionType ct)
	{
		checkNode(ct);
		if (ct.params.length != ct.isArgRef.length ||
		    ct.params.length != ct.isArgOut.length) {
			throw panic(ct, "isArg[Ref|Out] length doesn't match");
		}
		return Continue;
	}

	override Status enter(ir.DelegateType ct)
	{
		checkNode(ct);
		if (ct.params.length != ct.isArgRef.length ||
		    ct.params.length != ct.isArgOut.length) {
			throw panic(ct, "isArg[Ref|Out] length doesn't match");
		}
		return Continue;
	}

	override Status enter(ir.TopLevelBlock tlb)
	{
		checkNode(tlb);
		foreach (n; tlb.nodes) {
			switch (n.nodeType) with (ir.NodeType) {
			case Import:
				// Check if in top level module.
				goto case;
			case Variable:
			case Function:
			case Alias:
			case Enum:
			case Struct:
			case Union:
			case Class:
			case Interface:
			case MixinFunction:
			case MixinTemplate:
			case MixinStatement:
			case EnumDeclaration:
			case AssertStatement:
			case TemplateDefinition:
			case TemplateInstance:
				auto s = accept(n, this);
				if (s == Stop)
					return Stop;
				break;
			default:
				auto str = format("%s invalid node '%s' in toplevel block",
				                  ir.getNodeAddressString(n),
				                  ir.nodeToString(n));
				throw panic(n, str);
			}
		}

		return ContinueParent;
	}

	override Status enter(ir.BlockStatement bs)
	{
		checkNode(bs);
		checkDepth(bs.myScope);
		foreach (n; bs.statements) {
			switch (n.nodeType) with (ir.NodeType) {
			case BlockStatement:
			case ReturnStatement:
			case IfStatement:
			case WhileStatement:
			case DoStatement:
			case ForStatement:
			case ForeachStatement:
			case BreakStatement:
			case ContinueStatement:
			case ExpStatement:
			case Variable:
			case MixinStatement:
			case ThrowStatement:
			case SwitchStatement:
			case GotoStatement:
			case AssertStatement:
			case WithStatement:
			case ScopeStatement:
			case TryStatement:
				auto s = accept(n, this);
				if (s == Stop)
					return Stop;
				break;
			case Function:
			case Struct:
				break;
			default:
				auto str = format("(%s) invalid node '%s' in block statement",
				                  ir.getNodeAddressString(n),
				                  ir.nodeToString(n));
				throw panic(n, str);
			}
		}

		return ContinueParent;
	}

	override Status visit(ref ir.Exp exp, ir.IdentifierExp ie)
	{
		checkNode(exp);
		auto str = format("%s IdentifierExp '%s' left in IR.",
		                  ir.getNodeAddressString(ie), ie.value);
		throw panic(ie, str);
	}

	override Status leave(ir.TopLevelBlock tlb) { assert(false); }
	override Status leave(ir.BlockStatement bs) { assert(false); }

	override Status enter(ir.Class n) { check(n); return super.enter(n); }
	override Status enter(ir.Struct n) { check(n); return super.enter(n); }
	override Status enter(ir.Union n) { check(n); return super.enter(n); }
	override Status enter(ir.Enum n) { checkStorage(n); return super.enter(n); }
	override Status enter(ir._Interface n) { check(n); return super.enter(n); }

	void check(ir.Aggregate a)
	{
		checkNode(a);
		checkDepth(a.myScope);
		checkStorage(a);
	}

	void checkStorage(ir.Type t)
	{
		if (t.isConst || t.isImmutable || t.isScope) {
			if (auto n = cast(ir.Named) t) {
				throw panic(t, format("type '%s' storage modifiers has been modified", n.name));
			} else {
				throw panic(t, "type storage modifiers has been modified");
			}
		}
	}

	void checkDepth(ir.Scope _scope)
	{
		auto fns = cast(int)functionStack.length;
		auto expectedDepth = fns <= 1 ? 0 : fns - 1;
		if (expectedDepth != _scope.nestedDepth) {
			auto str = format("nested depth incorrectly set to %s, expected %s.",
			                  _scope.nestedDepth, expectedDepth);
			throw panic(/*#ref*/_scope.node.loc, str);
		}
	}

public:
	Status checkNode(ir.Node n)
	{
		auto t = n.uniqueId;
		if (t in mNodes) {
			auto str = format(
				"%s \"%s\" node found more then once in IR",
				ir.getNodeAddressString(n), ir.nodeToString(n));
			throw panic(n, str);
		}
		mNodes[t] = mCount++;
		return Continue;
	}

	override Status enter(ir.Module m) { super.enter(m); return checkNode(m); }
	override Status enter(ir.Import i) { return checkNode(i); }
	override Status enter(ir.Unittest u) { return checkNode(u); }
	override Status enter(ir.FunctionParam fp) { return checkNode(fp); }
	override Status enter(ir.Condition c) { return checkNode(c); }
	override Status enter(ir.ConditionTopLevel ctl) { return checkNode(ctl); }
	override Status enter(ir.MixinFunction mf) { return checkNode(mf); }
	override Status enter(ir.MixinTemplate mt) { return checkNode(mt); }

	override Status visit(ir.QualifiedName qname) { return checkNode(qname); }
	override Status visit(ir.Identifier name) { return checkNode(name); }

	/*
	 * Statement Nodes.
	 */
	override Status enter(ir.ExpStatement e) { return checkNode(e); }
	override Status enter(ir.ReturnStatement ret) { return checkNode(ret); }
	override Status enter(ir.AsmStatement a) { return checkNode(a); }
	override Status enter(ir.IfStatement i)  { return checkNode(i); }
	override Status enter(ir.WhileStatement w) { return checkNode(w); }
	override Status enter(ir.DoStatement d) { return checkNode(d); }
	override Status enter(ir.ForStatement f) { return checkNode(f); }
	override Status enter(ir.ForeachStatement fes) { return checkNode(fes); }
	override Status enter(ir.LabelStatement ls) { return checkNode(ls); }
	override Status enter(ir.SwitchStatement ss) { return checkNode(ss); }
	override Status enter(ir.SwitchCase c) { return checkNode(c); }
	override Status enter(ir.GotoStatement gs) { return checkNode(gs); }
	override Status enter(ir.WithStatement ws) { return checkNode(ws); }
	override Status enter(ir.SynchronizedStatement ss) { return checkNode(ss); }
	override Status enter(ir.TryStatement ts) { return checkNode(ts); }
	override Status enter(ir.ThrowStatement ts) { return checkNode(ts); }
	override Status enter(ir.ScopeStatement ss) { return checkNode(ss); }
	override Status enter(ir.PragmaStatement ps) { return checkNode(ps); }
	override Status enter(ir.ConditionStatement cs) { return checkNode(cs); }
	override Status enter(ir.MixinStatement ms) { return checkNode(ms); }
	override Status enter(ir.AssertStatement as) { return checkNode(as); }

	override Status visit(ir.BreakStatement bs) { return checkNode(bs); }
	override Status visit(ir.ContinueStatement cs) { return checkNode(cs); }

	/*
	 * Declaration
	 */
	override Status enter(ir.PointerType pointer) { return checkNode(pointer); }
	override Status enter(ir.ArrayType array) { return checkNode(array); }
	override Status enter(ir.StaticArrayType array) { return checkNode(array); }
	override Status enter(ir.AmbiguousArrayType array) { return checkNode(array); }
	override Status enter(ir.Function func) { super.enter(func); return checkNode(func); }
	override Status enter(ir.Attribute attr) { return checkNode(attr); }
	override Status enter(ir.Alias a) { return checkNode(a); }
	override Status enter(ir.TypeOf typeOf) { return checkNode(typeOf); }
	override Status enter(ir.EnumDeclaration ed) { return checkNode(ed); }

	override Status visit(ir.PrimitiveType it) { return checkNode(it); }
	override Status visit(ir.NullType nt) { return checkNode(nt); }
	override Status visit(ir.AutoType at) { return checkNode(at); }
	override Status visit(ir.NoType at) { return checkNode(at); }

	/*
	 * Template Nodes.
	 */
	override Status visit(ir.TemplateDefinition td) { return checkNode(td); }


	/*
	 * Expression Nodes.
	 */
	override Visitor.Status enter(ref ir.Exp e, ir.Postfix) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.Unary) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.BinOp) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.Ternary) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.ArrayLiteral) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.AssocArray) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.Assert) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.StringImport) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.Typeid) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.IsExp) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.FunctionLiteral) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.StructLiteral) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.UnionLiteral) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.ClassLiteral) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.Constant) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.TypeExp) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.StatementExp) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.VaArgExp) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.PropertyExp) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.BuiltinExp) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.AccessExp) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.RunExp) { return checkNode(e); }
	override Visitor.Status enter(ref ir.Exp e, ir.ComposableString) { return checkNode(e); }

	override Visitor.Status visit(ref ir.Exp e, ir.ExpReference) { return checkNode(e); }
	override Visitor.Status visit(ref ir.Exp e, ir.TokenExp) { return checkNode(e); }
	override Visitor.Status visit(ref ir.Exp e, ir.StoreExp) { return checkNode(e); }
}