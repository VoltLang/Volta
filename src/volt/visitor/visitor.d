// Copyright © 2012, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.visitor;

import std.conv : to;
import std.string : format;

import volt.exceptions;
import ir = volt.ir.ir;


class Visitor
{
public:
	enum Status {
		Stop,
		Continue,
		ContinueParent,
	}

	alias Status.Stop Stop;
	alias Status.Continue Continue;
	alias Status.ContinueParent ContinueParent;

public abstract:

	/*
	 * Base.
	 */
	Status enter(ir.Module m);
	Status leave(ir.Module m);
	Status enter(ir.TopLevelBlock tlb);
	Status leave(ir.TopLevelBlock tlb);
	Status enter(ir.Import i);
	Status leave(ir.Import i);
	Status enter(ir.Unittest u);
	Status leave(ir.Unittest u);
	Status enter(ir.Class c);
	Status leave(ir.Class c);
	Status enter(ir._Interface i);
	Status leave(ir._Interface i);
	Status enter(ir.Struct s);
	Status leave(ir.Struct s);
	Status enter(ir.Variable d);
	Status leave(ir.Variable d);
	Status enter(ir.Enum e);
	Status leave(ir.Enum e);
	Status enter(ir.StaticAssert sa);
	Status leave(ir.StaticAssert sa);
	Status enter(ir.Condition c);
	Status leave(ir.Condition c);
	Status enter(ir.ConditionTopLevel ctl);
	Status leave(ir.ConditionTopLevel ctl);

	Status visit(ir.EmptyTopLevel empty);
	Status visit(ir.QualifiedName qname);
	Status visit(ir.Identifier name);

	/*
	 * Statement Nodes.
	 */
	Status enter(ir.ExpStatement e);
	Status leave(ir.ExpStatement e);
	Status enter(ir.ReturnStatement ret);
	Status leave(ir.ReturnStatement ret);
	Status enter(ir.BlockStatement b);
	Status leave(ir.BlockStatement b);
	Status enter(ir.AsmStatement a);
	Status leave(ir.AsmStatement a);
	Status enter(ir.IfStatement i);
	Status leave(ir.IfStatement i);
	Status enter(ir.WhileStatement w);
	Status leave(ir.WhileStatement w);
	Status enter(ir.DoStatement d);
	Status leave(ir.DoStatement d);
	Status enter(ir.ForStatement f);
	Status leave(ir.ForStatement f);
	Status enter(ir.LabelStatement ls);
	Status leave(ir.LabelStatement ls);
	Status enter(ir.SwitchStatement ss);
	Status leave(ir.SwitchStatement ss);
	Status enter(ir.SwitchCase c);
	Status leave(ir.SwitchCase c);
	Status enter(ir.GotoStatement gs);
	Status leave(ir.GotoStatement gs);
	Status enter(ir.WithStatement ws);
	Status leave(ir.WithStatement ws);
	Status enter(ir.SynchronizedStatement ss);
	Status leave(ir.SynchronizedStatement ss);
	Status enter(ir.TryStatement ts);
	Status leave(ir.TryStatement ts);
	Status enter(ir.ThrowStatement ts);
	Status leave(ir.ThrowStatement ts);
	Status enter(ir.ScopeStatement ss);
	Status leave(ir.ScopeStatement ss);
	Status enter(ir.PragmaStatement ps);
	Status leave(ir.PragmaStatement ps);
	Status enter(ir.ConditionStatement cs);
	Status leave(ir.ConditionStatement cs);

	Status visit(ir.BreakStatement bs);
	Status visit(ir.ContinueStatement cs);
	Status visit(ir.EmptyStatement es);

	/*
	 * Declaration
	 */
	Status enter(ir.PointerType pointer);
	Status leave(ir.PointerType pointer);
	Status enter(ir.ArrayType array);
	Status leave(ir.ArrayType array);
	Status enter(ir.StaticArrayType array);
	Status leave(ir.StaticArrayType array);
	Status enter(ir.AAType array);
	Status leave(ir.AAType array);
	Status enter(ir.FunctionType fn);
	Status leave(ir.FunctionType fn);
	Status enter(ir.DelegateType fn);
	Status leave(ir.DelegateType fn);
	Status enter(ir.Function fn);
	Status leave(ir.Function fn);
	Status enter(ir.StorageType type);
	Status leave(ir.StorageType type);
	Status enter(ir.Attribute attr);
	Status leave(ir.Attribute attr);
	Status enter(ir.Alias a);
	Status leave(ir.Alias a);
	Status enter(ir.TypeOf typeOf);
	Status leave(ir.TypeOf typeOf);

	Status visit(ir.PrimitiveType it);
	Status visit(ir.TypeReference tr);


	/*
	 * Expression Nodes.
	 */
	Status enter(ir.Postfix);
	Status leave(ir.Postfix);
	Status enter(ir.Unary);
	Status leave(ir.Unary);
	Status enter(ir.BinOp);
	Status leave(ir.BinOp);
	Status enter(ir.Ternary);
	Status leave(ir.Ternary);
	Status enter(ir.ArrayLiteral);
	Status leave(ir.ArrayLiteral);
	Status enter(ir.AssocArray);
	Status leave(ir.AssocArray);
	Status enter(ir.Assert);
	Status leave(ir.Assert);
	Status enter(ir.StringImport);
	Status leave(ir.StringImport);
	Status enter(ir.Typeid);
	Status leave(ir.Typeid);
	Status enter(ir.IsExp);
	Status leave(ir.IsExp);
	Status enter(ir.FunctionLiteral);
	Status leave(ir.FunctionLiteral);
	Status enter(ir.StructLiteral);
	Status leave(ir.StructLiteral);
	Status enter(ir.ClassLiteral);
	Status leave(ir.ClassLiteral);

	Status visit(ir.ExpReference);
	Status visit(ir.Constant);
	Status visit(ir.IdentifierExp);

	Status debugVisitNode(ir.Node n);
}

alias Visitor.Status.Stop VisitorStop;
alias Visitor.Status.Continue VisitorContinue;
alias Visitor.Status.ContinueParent VisitorContinueParent;

/// A visitor that does nothing.
class NullVisitor : Visitor
{
public:
override:
	Status enter(ir.Module m){ return Continue; }
	Status leave(ir.Module m){ return Continue; }
	Status enter(ir.TopLevelBlock tlb) { return Continue; }
	Status leave(ir.TopLevelBlock tlb) { return Continue; } 
	Status enter(ir.Import i){ return Continue; }
	Status leave(ir.Import i){ return Continue; }
	Status enter(ir.Unittest u){ return Continue; }
	Status leave(ir.Unittest u){ return Continue; }
	Status enter(ir.Class c){ return Continue; }
	Status leave(ir.Class c){ return Continue; }
	Status enter(ir._Interface i){ return Continue; }
	Status leave(ir._Interface i){ return Continue; }
	Status enter(ir.Struct s){ return Continue; }
	Status leave(ir.Struct s){ return Continue; }
	Status enter(ir.Variable d){ return Continue; }
	Status leave(ir.Variable d){ return Continue; }
	Status enter(ir.Enum e){ return Continue; }
	Status leave(ir.Enum e){ return Continue; }
	Status enter(ir.StaticAssert sa){ return Continue; }
	Status leave(ir.StaticAssert sa){ return Continue; }
	Status enter(ir.Condition c){ return Continue; }
	Status leave(ir.Condition c){ return Continue; }
	Status enter(ir.ConditionTopLevel ctl){ return Continue; }
	Status leave(ir.ConditionTopLevel ctl){ return Continue; }
	Status visit(ir.EmptyTopLevel empty){ return Continue; }
	Status visit(ir.QualifiedName qname){ return Continue; }
	Status visit(ir.Identifier name){ return Continue; }

	/*
	 * Statement Nodes.
	 */
	Status enter(ir.ExpStatement e){ return Continue; }
	Status leave(ir.ExpStatement e){ return Continue; }
	Status enter(ir.ReturnStatement ret){ return Continue; }
	Status leave(ir.ReturnStatement ret){ return Continue; }
	Status enter(ir.BlockStatement b){ return Continue; }
	Status leave(ir.BlockStatement b){ return Continue; }
	Status enter(ir.AsmStatement a){ return Continue; }
	Status leave(ir.AsmStatement a){ return Continue; }
	Status enter(ir.IfStatement i){ return Continue; }
	Status leave(ir.IfStatement i){ return Continue; }
	Status enter(ir.WhileStatement w){ return Continue; }
	Status leave(ir.WhileStatement w){ return Continue; }
	Status enter(ir.DoStatement d){ return Continue; }
	Status leave(ir.DoStatement d){ return Continue; }
	Status enter(ir.ForStatement f){ return Continue; }
	Status leave(ir.ForStatement f){ return Continue; }
	Status enter(ir.LabelStatement ls){ return Continue; }
	Status leave(ir.LabelStatement ls){ return Continue; }
	Status enter(ir.SwitchStatement ss){ return Continue; }
	Status leave(ir.SwitchStatement ss){ return Continue; }
	Status enter(ir.SwitchCase c){ return Continue; }
	Status leave(ir.SwitchCase c){ return Continue; }
	Status enter(ir.GotoStatement gs){ return Continue; }
	Status leave(ir.GotoStatement gs){ return Continue; }
	Status enter(ir.WithStatement ws){ return Continue; }
	Status leave(ir.WithStatement ws){ return Continue; }
	Status enter(ir.SynchronizedStatement ss){ return Continue; }
	Status leave(ir.SynchronizedStatement ss){ return Continue; }
	Status enter(ir.TryStatement ts){ return Continue; }
	Status leave(ir.TryStatement ts){ return Continue; }
	Status enter(ir.ThrowStatement ts){ return Continue; }
	Status leave(ir.ThrowStatement ts){ return Continue; }
	Status enter(ir.ScopeStatement ss){ return Continue; }
	Status leave(ir.ScopeStatement ss){ return Continue; }
	Status enter(ir.PragmaStatement ps){ return Continue; }
	Status leave(ir.PragmaStatement ps){ return Continue; }
	Status enter(ir.ConditionStatement cs){ return Continue; }
	Status leave(ir.ConditionStatement cs){ return Continue; }

	Status visit(ir.ContinueStatement cs){ return Continue; }
	Status visit(ir.BreakStatement bs){ return Continue; }
	Status visit(ir.EmptyStatement es){ return Continue; }

	/*
	 * Declaration
	 */
	Status enter(ir.PointerType pointer){ return Continue; }
	Status leave(ir.PointerType pointer){ return Continue; }
	Status enter(ir.ArrayType array){ return Continue; }
	Status leave(ir.ArrayType array){ return Continue; }
	Status enter(ir.StaticArrayType array){ return Continue; }
	Status leave(ir.StaticArrayType array){ return Continue; }
	Status enter(ir.AAType array){ return Continue; }
	Status leave(ir.AAType array){ return Continue; }
	Status enter(ir.FunctionType fn){ return Continue; }
	Status leave(ir.FunctionType fn){ return Continue; }
	Status enter(ir.DelegateType fn){ return Continue; }
	Status leave(ir.DelegateType fn){ return Continue; }
	Status enter(ir.Function fn){ return Continue; }
	Status leave(ir.Function fn){ return Continue; }
	Status enter(ir.StorageType type){ return Continue; }
	Status leave(ir.StorageType type){ return Continue; }
	Status enter(ir.Attribute attr){ return Continue; }
	Status leave(ir.Attribute attr){ return Continue; }
	Status enter(ir.Alias a){ return Continue; }
	Status leave(ir.Alias a){ return Continue; }

	Status visit(ir.PrimitiveType it){ return Continue; }
	Status visit(ir.TypeReference tr){ return Continue; }

	/*
	 * Expression Nodes.
	 */
	Status enter(ir.Postfix){ return Continue; }
	Status leave(ir.Postfix){ return Continue; }
	Status enter(ir.Unary){ return Continue; }
	Status leave(ir.Unary){ return Continue; }
	Status enter(ir.BinOp){ return Continue; }
	Status leave(ir.BinOp){ return Continue; }
	Status enter(ir.Ternary){ return Continue; }
	Status leave(ir.Ternary){ return Continue; }
	Status enter(ir.ArrayLiteral){ return Continue; }
	Status leave(ir.ArrayLiteral){ return Continue; }
	Status enter(ir.AssocArray){ return Continue; }
	Status leave(ir.AssocArray){ return Continue; }
	Status enter(ir.Assert){ return Continue; }
	Status leave(ir.Assert){ return Continue; }
	Status enter(ir.StringImport){ return Continue; }
	Status leave(ir.StringImport){ return Continue; }
	Status enter(ir.Typeid){ return Continue; }
	Status leave(ir.Typeid){ return Continue; }
	Status enter(ir.IsExp){ return Continue; }
	Status leave(ir.IsExp){ return Continue; }
	Status enter(ir.FunctionLiteral){ return Continue; }
	Status leave(ir.FunctionLiteral){ return Continue; }
	Status enter(ir.StructLiteral){ return Continue; }
	Status leave(ir.StructLiteral){ return Continue; }
	Status enter(ir.ClassLiteral){ return Continue; }
	Status leave(ir.ClassLiteral){ return Continue; }
	Status enter(ir.TypeOf typeOf) { return Continue; }
	Status leave(ir.TypeOf typeOf) { return Continue; }

	Status visit(ir.ExpReference){ return Continue; }
	Status visit(ir.Constant){ return Continue; }
	Status visit(ir.IdentifierExp){ return Continue; }

	Status debugVisitNode(ir.Node) { return Continue; }
}


/**
 * Helper function that returns VistorContinue if @s is
 * VisitorContinueParent, used to abort a leaf node, but
 * not the whole tree.
 */
Visitor.Status parentContinue(Visitor.Status s)
{
	return s == VisitorContinueParent ? VisitorContinue : s;
}




Visitor.Status accept(ir.Node n, Visitor av)
{
	auto status = av.debugVisitNode(n);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	switch (n.nodeType) {
	/*
	 * Top Levels.
	 */
	case ir.NodeType.Module:
		return acceptModule(cast(ir.Module) n, av);
	case ir.NodeType.TopLevelBlock:
		auto asTlb = cast(ir.TopLevelBlock) n;
		assert(asTlb !is null);
		return acceptTopLevelBlock(asTlb, av);
	case ir.NodeType.Import:
		auto asImport = cast(ir.Import) n;
		assert(asImport !is null);
		return acceptImport(asImport, av);
	case ir.NodeType.Variable:
		return acceptVariable(cast(ir.Variable) n, av);
	case ir.NodeType.Unittest:
		return acceptUnittest(cast(ir.Unittest) n, av);
	case ir.NodeType.Class:
		auto asClass = cast(ir.Class) n;
		assert(asClass !is null);
		return acceptClass(asClass, av);
	case ir.NodeType.Interface:
		auto asInterface = cast(ir._Interface) n;
		assert(asInterface !is null);
		return acceptInterface(asInterface, av);
	case ir.NodeType.Struct:
		return acceptStruct(cast(ir.Struct) n, av);
	case ir.NodeType.Enum:
		auto asEnum = cast(ir.Enum) n;
		assert(asEnum !is null);
		return acceptEnum(asEnum, av);
	case ir.NodeType.Attribute:
		auto asAttribute = cast(ir.Attribute) n;
		assert(asAttribute !is null);
		return acceptAttribute(asAttribute, av);
	case ir.NodeType.StaticAssert:
		auto asStaticAssert = cast(ir.StaticAssert) n;
		assert(asStaticAssert !is null);
		return acceptStaticAssert(asStaticAssert, av);
	case ir.NodeType.EmptyTopLevel:
		auto asEmpty = cast(ir.EmptyTopLevel) n;
		assert(asEmpty !is null);
		return av.visit(asEmpty);
	case ir.NodeType.ConditionTopLevel:
		auto asCtl = cast(ir.ConditionTopLevel) n;
		assert(asCtl !is null);
		return acceptConditionTopLevel(asCtl, av);
	case ir.NodeType.Condition:
		auto asCondition = cast(ir.Condition) n;
		assert(asCondition !is null);
		return acceptCondition(asCondition, av);
	case ir.NodeType.QualifiedName:
		auto asQname = cast(ir.QualifiedName) n;
		assert(asQname !is null);
		return av.visit(asQname);
	case ir.NodeType.Identifier:
		auto asName = cast(ir.Identifier) n;
		assert(asName !is null);
		return av.visit(asName);

	/*
	 * Expressions.
	 */
	case ir.NodeType.Constant:
		return acceptConstant(cast(ir.Constant) n, av);
	case ir.NodeType.IdentifierExp:
		return acceptIdentifier(cast(ir.IdentifierExp) n, av);
	case ir.NodeType.Postfix:
		return acceptPostfix(cast(ir.Postfix) n, av);
	case ir.NodeType.Unary:
		return acceptUnary(cast(ir.Unary) n, av);
	case ir.NodeType.BinOp:
		return acceptBinOp(cast(ir.BinOp) n, av);
	case ir.NodeType.Ternary:
		return acceptTernary(cast(ir.Ternary) n, av);
	case ir.NodeType.ArrayLiteral:
		return acceptArrayLiteral(cast(ir.ArrayLiteral) n, av);
	case ir.NodeType.AssocArray:
		return acceptAssocArray(cast(ir.AssocArray) n, av);
	case ir.NodeType.Assert:
		return acceptAssert(cast(ir.Assert) n, av);
	case ir.NodeType.StringImport:
		return acceptStringImport(cast(ir.StringImport) n, av);
	case ir.NodeType.Typeid:
		return acceptTypeid(cast(ir.Typeid) n, av);
	case ir.NodeType.IsExp:
		auto asIs = cast(ir.IsExp) n;
		assert(asIs !is null);
		return acceptIsExp(asIs, av);
	case ir.NodeType.FunctionLiteral:
		auto asFunctionLiteral = cast(ir.FunctionLiteral) n;
		assert(asFunctionLiteral !is null);
		return acceptFunctionLiteral(asFunctionLiteral, av);
	case ir.NodeType.ExpReference:
		auto asExpReference = cast(ir.ExpReference) n;
		assert(asExpReference !is null);
		return av.visit(asExpReference);
	case ir.NodeType.StructLiteral:
		auto asStructLiteral = cast(ir.StructLiteral) n;
		assert(asStructLiteral !is null);
		return acceptStructLiteral(asStructLiteral, av);
	case ir.NodeType.ClassLiteral:
		auto asClassLiteral = cast(ir.ClassLiteral) n;
		assert(asClassLiteral !is null);
		return acceptClassLiteral(asClassLiteral, av);

	/*
	 * Statements.
	 */
	case ir.NodeType.ExpStatement:
		return acceptExpStatement(cast(ir.ExpStatement) n, av);
	case ir.NodeType.ReturnStatement:
		return acceptReturnStatement(cast(ir.ReturnStatement) n, av);
	case ir.NodeType.BlockStatement:
		return acceptBlockStatement(cast(ir.BlockStatement) n, av);
	case ir.NodeType.AsmStatement:
		return acceptAsmStatement(cast(ir.AsmStatement) n, av);
	case ir.NodeType.IfStatement:
		return acceptIfStatement(cast(ir.IfStatement) n, av);
	case ir.NodeType.WhileStatement:
		return acceptWhileStatement(cast(ir.WhileStatement) n, av);
	case ir.NodeType.DoStatement:
		return acceptDoStatement(cast(ir.DoStatement) n, av);
	case ir.NodeType.ForStatement:
		return acceptForStatement(cast(ir.ForStatement) n, av);
	case ir.NodeType.LabelStatement:
		return acceptLabelStatement(cast(ir.LabelStatement) n, av);
	case ir.NodeType.SwitchStatement:
		return acceptSwitchStatement(cast(ir.SwitchStatement) n, av);
	case ir.NodeType.ContinueStatement:
		auto asCont = cast(ir.ContinueStatement) n;
		assert(asCont !is null);
		return av.visit(asCont);
	case ir.NodeType.BreakStatement:
		auto asBreak = cast(ir.BreakStatement) n;
		assert(asBreak !is null);
		return av.visit(asBreak);
	case ir.NodeType.GotoStatement:
		return acceptGotoStatement(cast(ir.GotoStatement) n, av);
	case ir.NodeType.WithStatement:
		return acceptWithStatement(cast(ir.WithStatement) n, av);
	case ir.NodeType.SynchronizedStatement:
		return acceptSynchronizedStatement(cast(ir.SynchronizedStatement) n, av);
	case ir.NodeType.TryStatement:
		auto asTry = cast(ir.TryStatement) n;
		assert(asTry !is null);
		return acceptTryStatement(asTry, av);
	case ir.NodeType.ThrowStatement:
		auto asThrow = cast(ir.ThrowStatement) n;
		assert(asThrow !is null);
		return acceptThrowStatement(asThrow, av);
	case ir.NodeType.ScopeStatement:
		auto asScope = cast(ir.ScopeStatement) n;
		assert(asScope !is null);
		return acceptScopeStatement(asScope, av);
	case ir.NodeType.PragmaStatement:
		auto asPragma = cast(ir.PragmaStatement) n;
		assert(asPragma !is null);
		return acceptPragmaStatement(asPragma, av);
	case ir.NodeType.EmptyStatement:
		auto asEmpty = cast(ir.EmptyStatement) n;
		assert(asEmpty !is null);
		return av.visit(asEmpty);
	case ir.NodeType.ConditionStatement:
		auto asCs = cast(ir.ConditionStatement) n;
		assert(asCs !is null);
		return acceptConditionStatement(asCs, av);

	/*
	 * Declarations.
	 */
	case ir.NodeType.Function:
		return acceptFunction(cast(ir.Function) n, av);
	case ir.NodeType.PrimitiveType:
		return av.visit(cast(ir.PrimitiveType) n);
	case ir.NodeType.TypeReference:
		auto asUser = cast(ir.TypeReference) n;
		assert(asUser !is null);
		return av.visit(asUser);
	case ir.NodeType.PointerType:
		return acceptPointerType(cast(ir.PointerType) n, av);
	case ir.NodeType.ArrayType:
		return acceptArrayType(cast(ir.ArrayType) n, av);
	case ir.NodeType.StaticArrayType:
		return acceptStaticArrayType(cast(ir.StaticArrayType) n, av);
	case ir.NodeType.AAType:
		return acceptAAType(cast(ir.AAType) n, av);
	case ir.NodeType.FunctionType:
		return acceptFunctionType(cast(ir.FunctionType) n, av);
	case ir.NodeType.DelegateType:
		return acceptDelegateType(cast(ir.DelegateType) n, av);
	case ir.NodeType.StorageType:
		return acceptStorageType(cast(ir.StorageType) n, av);
	case ir.NodeType.Alias:
		return acceptAlias(cast(ir.Alias) n, av);
	case ir.NodeType.TypeOf:
		auto typeOf = cast(ir.TypeOf) n;
		assert(typeOf !is null);
		return acceptTypeOf(typeOf, av);

	/*
	 * Failure fall through.
	 */
	default:
		throw CompilerPanic(n.location, format("unhandled accept node: %s.", to!string(n.nodeType)));
	}
}

/*
 * Top levels.
 */

Visitor.Status acceptModule(ir.Module m, Visitor av)
{
	auto status = av.enter(m);
	if (status != VisitorContinue)
		return parentContinue(status);

	status = accept(m.children, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(m);
}

Visitor.Status acceptTopLevelBlock(ir.TopLevelBlock tlb, Visitor av)
{
	auto status = av.enter(tlb);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (n; tlb.nodes) {
		accept(n, av);
	}

	return av.leave(tlb);
}

Visitor.Status acceptImport(ir.Import i, Visitor av)
{
	auto status = av.enter(i);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	return av.leave(i);
}

Visitor.Status acceptVariable(ir.Variable d, Visitor av)
{
	auto status = av.enter(d);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(d.type, av);
	if (status == VisitorStop) {
		return status;
	}

	if (d.assign !is null) {
		status = accept(d.assign, av);
		if (status == VisitorStop) {
			return status;
		}
	}

	return av.leave(d);
}

Visitor.Status acceptUnittest(ir.Unittest u, Visitor av)
{
	auto status = av.enter(u);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (statement; u._body.statements) {
		accept(statement, av);
	}

	return av.leave(u);
}

Visitor.Status acceptClass(ir.Class c, Visitor av)
{
	auto status = av.enter(c);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(c.members, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(c);
}

Visitor.Status acceptInterface(ir._Interface i, Visitor av)
{
	auto status = av.enter(i);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(i.members, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(i);
}

Visitor.Status acceptStruct(ir.Struct s, Visitor av)
{
	auto status = av.enter(s);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(s.members, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(s);
}

Visitor.Status acceptEnum(ir.Enum e, Visitor av)
{
	auto status = av.enter(e);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	return av.leave(e);
}

Visitor.Status acceptStaticAssert(ir.StaticAssert sa, Visitor av)
{
	auto status = av.enter(sa);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(sa.exp, av);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (sa.message !is null) {
		status = accept(sa.message, av);
		if (status != VisitorContinue) {
			return parentContinue(status);
		}
	}

	return av.leave(sa);
}

Visitor.Status acceptCondition(ir.Condition c, Visitor av)
{
	auto status = av.enter(c);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	return av.leave(c);
}

Visitor.Status acceptConditionTopLevel(ir.ConditionTopLevel ctl, Visitor av)
{
	auto status = av.enter(ctl);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(ctl.condition, av);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (member; ctl.members.nodes) {
		accept(member, av);
	}

	if (ctl.elsePresent) {
		foreach (member; ctl._else.nodes) {
			status = accept(member, av);
			if (status == VisitorStop) {
				return VisitorStop;
			}
		}
	}

	return av.leave(ctl);
}

/*
 * Declarations.
 */

Visitor.Status acceptAttribute(ir.Attribute attr, Visitor av)
{
	auto status = av.enter(attr);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (toplevel; attr.members.nodes) {
		status = accept(toplevel, av);
		if (status != VisitorContinue) {
			return parentContinue(status);
		}
	}

	return av.leave(attr);
}

Visitor.Status acceptAlias(ir.Alias a, Visitor av)
{
	auto status = av.enter(a);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(a.type, av);
	if (status == VisitorStop) {
		return status;
	}

	return av.leave(a);
}

Visitor.Status acceptTypeOf(ir.TypeOf typeOf, Visitor av)
{
	auto status = av.enter(typeOf);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(typeOf.exp, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(typeOf);
}

Visitor.Status acceptStorageType(ir.StorageType type, Visitor av)
{
	auto status = av.enter(type);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (type.base !is null) {
		status = accept(type.base, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(type);
}

Visitor.Status acceptPointerType(ir.PointerType pointer, Visitor av)
{
	auto status = av.enter(pointer);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	assert(pointer.base !is null);
	status = accept(pointer.base, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(pointer);
}

Visitor.Status acceptArrayType(ir.ArrayType array, Visitor av)
{
	auto status = av.enter(array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(array.base, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(array);
}

Visitor.Status acceptStaticArrayType(ir.StaticArrayType array, Visitor av)
{
	auto status = av.enter(array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(array.base, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(array);
}

Visitor.Status acceptAAType(ir.AAType array, Visitor av)
{
	auto status = av.enter(array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(array.value, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}
	status = accept(array.key, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(array);
}

Visitor.Status acceptFunctionType(ir.FunctionType fn, Visitor av)
{
	auto status = av.enter(fn);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(fn.ret, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	foreach (param; fn.params) {
		status = accept(param.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(fn);
}

Visitor.Status acceptDelegateType(ir.DelegateType fn, Visitor av)
{
	auto status = av.enter(fn);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(fn.ret, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}
	foreach (param; fn.params) {
		status = accept(param.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(fn);
}

Visitor.Status acceptFunction(ir.Function fn, Visitor av)
{
	auto status = av.enter(fn);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(fn.type, av);
	if (status == VisitorStop)
		return status;

	if (fn.inContract !is null) {
		status = accept(fn.inContract, av);
		if (status == VisitorStop)
			return status;
	}

	if (fn.outContract !is null) {
		status = accept(fn.outContract, av);
		if (status == VisitorStop)
			return status;
	}

	if (fn._body !is null) {
		status = accept(fn._body, av);
		if (status == VisitorStop)
			return status;
	}

	return av.leave(fn);
}

/*
 * Statements.
 */

Visitor.Status acceptExpStatement(ir.ExpStatement e, Visitor av)
{
	auto status = av.enter(e);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(e.exp, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(e);
}

Visitor.Status acceptReturnStatement(ir.ReturnStatement ret, Visitor av)
{
	auto status = av.enter(ret);
	if (status != VisitorContinue)
		return parentContinue(status);

	if (ret.exp !is null) {
		status = accept(ret.exp, av);
		if (status == VisitorStop)
			return VisitorStop;
	}

	return av.leave(ret);
}

Visitor.Status acceptBlockStatement(ir.BlockStatement b, Visitor av)
{
	auto status = av.enter(b);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	auto statements = b.statements;
	foreach (statement; statements) {
		status = accept(statement, av);
		if (status != VisitorContinue) {
			return parentContinue(status);
		}
	}

	return av.leave(b);
}

Visitor.Status acceptAsmStatement(ir.AsmStatement a, Visitor av)
{
	auto status = av.enter(a);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	return av.leave(a);
}

Visitor.Status acceptIfStatement(ir.IfStatement i, Visitor av)
{
	auto status = av.enter(i);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(i.exp, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = accept(i.thenState, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	if (i.elseState !is null) {
		status = accept(i.elseState, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(i);
}

Visitor.Status acceptWhileStatement(ir.WhileStatement w, Visitor av)
{
	auto status = av.enter(w);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(w.condition, av);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	accept(w.block, av);

	return av.leave(w);
}

Visitor.Status acceptDoStatement(ir.DoStatement d, Visitor av)
{
	auto status = av.enter(d);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	accept(d.block, av);

	status = accept(d.condition, av);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	return av.leave(d);
}

Visitor.Status acceptForStatement(ir.ForStatement f, Visitor av)
{
	auto status = av.enter(f);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (i; f.initVars) {
		accept(i, av);
	}
	foreach (i; f.initExps) {
		accept(i, av);
	}

	if (f.test !is null) {
		accept(f.test, av);
	}

	if (f.block !is null) {
		accept(f.block, av);
	}

	foreach (increment; f.increments) {
		accept(increment, av);
	}

	return av.leave(f);
}

Visitor.Status acceptLabelStatement(ir.LabelStatement ls, Visitor av)
{
	auto status = av.enter(ls);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (statement; ls.childStatement) {
		accept(statement, av);
	}

	return av.leave(ls);
}

Visitor.Status acceptSwitchStatement(ir.SwitchStatement ss, Visitor av)
{
	auto status = av.enter(ss);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (_case; ss.cases) {
		status = av.enter(_case);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(ss);
}

Visitor.Status acceptGotoStatement(ir.GotoStatement gs, Visitor av)
{
	auto status = av.enter(gs);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	return av.leave(gs);
}

Visitor.Status acceptWithStatement(ir.WithStatement ws, Visitor av)
{
	auto status = av.enter(ws);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	av.enter(ws.block);

	return av.leave(ws);
}

Visitor.Status acceptSynchronizedStatement(ir.SynchronizedStatement ss, Visitor av)
{
	auto status = av.enter(ss);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	av.enter(ss.block);

	return av.leave(ss);
}

Visitor.Status acceptTryStatement(ir.TryStatement ts, Visitor av)
{
	auto status = av.enter(ts);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	return av.leave(ts);
}

Visitor.Status acceptThrowStatement(ir.ThrowStatement ts, Visitor av)
{
	auto status = av.enter(ts);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	accept(ts.exp, av);

	return av.leave(ts);
}

Visitor.Status acceptScopeStatement(ir.ScopeStatement ss, Visitor av)
{
	auto status = av.enter(ss);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	accept(ss.block, av);

	return av.leave(ss);
}

Visitor.Status acceptPragmaStatement(ir.PragmaStatement ps, Visitor av)
{
	auto status = av.enter(ps);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	accept(ps.block, av);

	return av.leave(ps);
}

Visitor.Status acceptConditionStatement(ir.ConditionStatement cs, Visitor av)
{
	auto status = av.enter(cs);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(cs.condition, av);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(cs.block, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	if (cs._else !is null) {
		status = accept(cs._else, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(cs);
}

/*
 * Expressions.
 */

Visitor.Status acceptPostfix(ir.Postfix postfix, Visitor av)
{
	auto status = av.enter(postfix);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(postfix.child, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	foreach (exp; postfix.arguments) {
		status = accept(exp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (postfix.identifier !is null) {
		status = accept(postfix.identifier, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (postfix.memberFunction !is null) {
		status = accept(postfix.memberFunction, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(postfix);
}

Visitor.Status acceptUnary(ir.Unary unary, Visitor av)
{
	auto status = av.enter(unary);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (unary.type !is null) {
		status = accept(unary.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (unary.value !is null) {
		status = accept(unary.value, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (unary.index !is null) {
		status = accept(unary.index, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	foreach (arg; unary.argumentList) {
		status = accept(arg, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(unary);
}

Visitor.Status acceptBinOp(ir.BinOp binop, Visitor av)
{
	auto status = av.enter(binop);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(binop.left, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = accept(binop.right, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(binop);
}

Visitor.Status acceptTernary(ir.Ternary ternary, Visitor av)
{
	auto status = av.enter(ternary);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(ternary.condition, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = accept(ternary.ifTrue, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = accept(ternary.ifFalse, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(ternary);
}

Visitor.Status acceptArrayLiteral(ir.ArrayLiteral array, Visitor av)
{
	auto status = av.enter(array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (array.type !is null) {
		status = accept(array.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	foreach (exp; array.values) {
		status = accept(exp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(array);
}

Visitor.Status acceptAssocArray(ir.AssocArray array, Visitor av)
{
	auto status = av.enter(array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (ref pair; array.pairs) {
		status = accept(pair.key, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
		status = accept(pair.value, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(array);
}

Visitor.Status acceptAssert(ir.Assert _assert, Visitor av)
{
	auto status = av.enter(_assert);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(_assert.condition, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	if (_assert.message !is null) {
		status = accept(_assert.message, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(_assert);
}

Visitor.Status acceptStringImport(ir.StringImport strimport, Visitor av)
{
	auto status = av.enter(strimport);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(strimport.filename, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(strimport);
}

Visitor.Status acceptTypeid(ir.Typeid ti, Visitor av)
{
	auto status = av.enter(ti);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (ti.exp !is null) {
		status = accept(ti.exp, av);
	} else {
		status = accept(ti.type, av);
	}
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(ti);
}

Visitor.Status acceptIsExp(ir.IsExp isExp, Visitor av)
{
	auto status = av.enter(isExp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(isExp.type, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	if (isExp.specType !is null) {
		status = accept(isExp.specType, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(isExp);
}

Visitor.Status acceptFunctionLiteral(ir.FunctionLiteral functionLiteral, Visitor av)
{
	auto status = av.enter(functionLiteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (statement; functionLiteral.block.statements) {
		status = accept(statement, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(functionLiteral);
}

/*
 * Literals.
 */

Visitor.Status acceptConstant(ir.Constant constant, Visitor av)
{
	auto status = av.visit(constant);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}
	return accept(constant.type, av);
}

Visitor.Status acceptIdentifier(ir.IdentifierExp identifier, Visitor av)
{
	return av.visit(identifier);
}

Visitor.Status acceptStructLiteral(ir.StructLiteral sliteral, Visitor av)
{
	auto status = av.enter(sliteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (exp; sliteral.exps) {
		status = accept(exp, av);
		if (status == VisitorContinueParent) {
			continue;
		} else if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (sliteral.type !is null) {
		status = accept(sliteral.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(sliteral);
}

Visitor.Status acceptClassLiteral(ir.ClassLiteral cliteral, Visitor av)
{
	auto status = av.enter(cliteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (exp; cliteral.exps) {
		status = accept(exp, av);
		if (status == VisitorContinueParent) {
			continue;
		} else if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (cliteral.type !is null) {
		status = accept(cliteral.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(cliteral);
}
