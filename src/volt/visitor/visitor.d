// Copyright © 2012, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.visitor;

import std.conv : to;
import std.string : format;

import volt.errors;
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
	Status enter(ir.Union c);
	Status leave(ir.Union c);
	Status enter(ir.Variable d);
	Status leave(ir.Variable d);
	Status enter(ir.FunctionParam fp);
	Status leave(ir.FunctionParam fp);
	Status enter(ir.Enum e);
	Status leave(ir.Enum e);
	Status enter(ir.StaticAssert sa);
	Status leave(ir.StaticAssert sa);
	Status enter(ir.Condition c);
	Status leave(ir.Condition c);
	Status enter(ir.ConditionTopLevel ctl);
	Status leave(ir.ConditionTopLevel ctl);
	Status enter(ir.MixinFunction mf);
	Status leave(ir.MixinFunction mf);
	Status enter(ir.MixinTemplate mt);
	Status leave(ir.MixinTemplate mt);
	Status enter(ir.UserAttribute ui);
	Status leave(ir.UserAttribute ui);

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
	Status enter(ir.ForeachStatement fes);
	Status leave(ir.ForeachStatement fes);
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
	Status enter(ir.MixinStatement ms);
	Status leave(ir.MixinStatement ms);
	Status enter(ir.AssertStatement as);
	Status leave(ir.AssertStatement as);
	
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
	Status enter(ir.EnumDeclaration);
	Status leave(ir.EnumDeclaration);

	Status visit(ir.PrimitiveType it);
	Status visit(ir.TypeReference tr);
	Status visit(ir.NullType nt);


	/*
	 * Expression Nodes.
	 */
	Visitor.Status enter(ref ir.Exp, ir.Postfix);
	Visitor.Status leave(ref ir.Exp, ir.Postfix);
	Visitor.Status enter(ref ir.Exp, ir.Unary);
	Visitor.Status leave(ref ir.Exp, ir.Unary);
	Visitor.Status enter(ref ir.Exp, ir.BinOp);
	Visitor.Status leave(ref ir.Exp, ir.BinOp);
	Visitor.Status enter(ref ir.Exp, ir.Ternary);
	Visitor.Status leave(ref ir.Exp, ir.Ternary);
	Visitor.Status enter(ref ir.Exp, ir.ArrayLiteral);
	Visitor.Status leave(ref ir.Exp, ir.ArrayLiteral);
	Visitor.Status enter(ref ir.Exp, ir.AssocArray);
	Visitor.Status leave(ref ir.Exp, ir.AssocArray);
	Visitor.Status enter(ref ir.Exp, ir.Assert);
	Visitor.Status leave(ref ir.Exp, ir.Assert);
	Visitor.Status enter(ref ir.Exp, ir.StringImport);
	Visitor.Status leave(ref ir.Exp, ir.StringImport);
	Visitor.Status enter(ref ir.Exp, ir.Typeid);
	Visitor.Status leave(ref ir.Exp, ir.Typeid);
	Visitor.Status enter(ref ir.Exp, ir.IsExp);
	Visitor.Status leave(ref ir.Exp, ir.IsExp);
	Visitor.Status enter(ref ir.Exp, ir.FunctionLiteral);
	Visitor.Status leave(ref ir.Exp, ir.FunctionLiteral);
	Visitor.Status enter(ref ir.Exp, ir.StructLiteral);
	Visitor.Status leave(ref ir.Exp, ir.StructLiteral);
	Visitor.Status enter(ref ir.Exp, ir.ClassLiteral);
	Visitor.Status leave(ref ir.Exp, ir.ClassLiteral);
	Visitor.Status enter(ref ir.Exp, ir.Constant);
	Visitor.Status leave(ref ir.Exp, ir.Constant);
	Visitor.Status enter(ref ir.Exp, ir.TypeExp);
	Visitor.Status leave(ref ir.Exp, ir.TypeExp);
	Visitor.Status enter(ref ir.Exp, ir.TemplateInstanceExp);
	Visitor.Status leave(ref ir.Exp, ir.TemplateInstanceExp);
	Visitor.Status enter(ref ir.Exp, ir.StatementExp);
	Visitor.Status leave(ref ir.Exp, ir.StatementExp);
	Visitor.Status enter(ref ir.Exp, ir.VaArgExp);
	Visitor.Status leave(ref ir.Exp, ir.VaArgExp);

	Visitor.Status visit(ref ir.Exp, ir.IdentifierExp);
	Visitor.Status visit(ref ir.Exp, ir.ExpReference);
	Visitor.Status visit(ref ir.Exp, ir.TraitsExp);
	Visitor.Status visit(ref ir.Exp, ir.TokenExp);

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
	Status enter(ir.Union u){ return Continue; }
	Status leave(ir.Union u){ return Continue; }
	Status enter(ir.Struct s){ return Continue; }
	Status leave(ir.Struct s){ return Continue; }
	Status enter(ir.Variable d){ return Continue; }
	Status leave(ir.Variable d){ return Continue; }
	Status enter(ir.FunctionParam fp){ return Continue; }
	Status leave(ir.FunctionParam fp){ return Continue; }
	Status enter(ir.Enum e){ return Continue; }
	Status leave(ir.Enum e){ return Continue; }
	Status enter(ir.StaticAssert sa){ return Continue; }
	Status leave(ir.StaticAssert sa){ return Continue; }
	Status enter(ir.Condition c){ return Continue; }
	Status leave(ir.Condition c){ return Continue; }
	Status enter(ir.ConditionTopLevel ctl){ return Continue; }
	Status leave(ir.ConditionTopLevel ctl){ return Continue; }
	Status enter(ir.UserAttribute ui){ return Continue; }
	Status leave(ir.UserAttribute ui){ return Continue; }
	Status visit(ir.EmptyTopLevel empty){ return Continue; }
	Status enter(ir.MixinFunction mf){ return Continue; }
	Status leave(ir.MixinFunction mf){ return Continue; }
	Status enter(ir.MixinTemplate mt){ return Continue; }
	Status leave(ir.MixinTemplate mt){ return Continue; }
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
	Status enter(ir.ForeachStatement fes){ return Continue; }
	Status leave(ir.ForeachStatement fes){ return Continue; }
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
	Status enter(ir.MixinStatement ms){ return Continue; }
	Status leave(ir.MixinStatement ms){ return Continue; }
	Status enter(ir.AssertStatement as){ return Continue; }
	Status leave(ir.AssertStatement as){ return Continue; }
	
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
	Status enter(ir.TypeOf to) { return Continue; }
	Status leave(ir.TypeOf to) { return Continue; }
	Status enter(ir.EnumDeclaration ed){ return Continue; }
	Status leave(ir.EnumDeclaration ed){ return Continue; }

	Status visit(ir.PrimitiveType it){ return Continue; }
	Status visit(ir.TypeReference tr){ return Continue; }
	Status visit(ir.NullType nt) { return Continue; }

	/*
	 * Expression Nodes.
	 */
	Status enter(ref ir.Exp, ir.Postfix){ return Continue; }
	Status leave(ref ir.Exp, ir.Postfix){ return Continue; }
	Status enter(ref ir.Exp, ir.Unary){ return Continue; }
	Status leave(ref ir.Exp, ir.Unary){ return Continue; }
	Status enter(ref ir.Exp, ir.BinOp){ return Continue; }
	Status leave(ref ir.Exp, ir.BinOp){ return Continue; }
	Status enter(ref ir.Exp, ir.Ternary){ return Continue; }
	Status leave(ref ir.Exp, ir.Ternary){ return Continue; }
	Status enter(ref ir.Exp, ir.ArrayLiteral){ return Continue; }
	Status leave(ref ir.Exp, ir.ArrayLiteral){ return Continue; }
	Status enter(ref ir.Exp, ir.AssocArray){ return Continue; }
	Status leave(ref ir.Exp, ir.AssocArray){ return Continue; }
	Status enter(ref ir.Exp, ir.Assert){ return Continue; }
	Status leave(ref ir.Exp, ir.Assert){ return Continue; }
	Status enter(ref ir.Exp, ir.StringImport){ return Continue; }
	Status leave(ref ir.Exp, ir.StringImport){ return Continue; }
	Status enter(ref ir.Exp, ir.Typeid){ return Continue; }
	Status leave(ref ir.Exp, ir.Typeid){ return Continue; }
	Status enter(ref ir.Exp, ir.IsExp){ return Continue; }
	Status leave(ref ir.Exp, ir.IsExp){ return Continue; }
	Status enter(ref ir.Exp, ir.FunctionLiteral){ return Continue; }
	Status leave(ref ir.Exp, ir.FunctionLiteral){ return Continue; }
	Status enter(ref ir.Exp, ir.StructLiteral){ return Continue; }
	Status leave(ref ir.Exp, ir.StructLiteral){ return Continue; }
	Status enter(ref ir.Exp, ir.ClassLiteral){ return Continue; }
	Status leave(ref ir.Exp, ir.ClassLiteral){ return Continue; }
	Status enter(ref ir.Exp, ir.Constant){ return Continue; }
	Status leave(ref ir.Exp, ir.Constant){ return Continue; }
	Status enter(ref ir.Exp, ir.TypeExp){ return Continue; }
	Status leave(ref ir.Exp, ir.TypeExp){ return Continue; }
	Status enter(ref ir.Exp, ir.TemplateInstanceExp){ return Continue; }
	Status leave(ref ir.Exp, ir.TemplateInstanceExp){ return Continue; }
	Status enter(ref ir.Exp, ir.StatementExp){ return Continue; }
	Status leave(ref ir.Exp, ir.StatementExp){ return Continue; }
	Status enter(ref ir.Exp, ir.VaArgExp){ return Continue; }
	Status leave(ref ir.Exp, ir.VaArgExp){ return Continue; }

	Status visit(ref ir.Exp, ir.ExpReference){ return Continue; }
	Status visit(ref ir.Exp, ir.IdentifierExp){ return Continue; }
	Status visit(ref ir.Exp, ir.TraitsExp){ return Continue; }
	Status visit(ref ir.Exp, ir.TokenExp){ return Continue; }

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

	final switch (n.nodeType) with (ir.NodeType) {
	/*
	 * Top Levels.
	 */
	case Module:
		return acceptModule(cast(ir.Module) n, av);
	case TopLevelBlock:
		auto asTlb = cast(ir.TopLevelBlock) n;
		assert(asTlb !is null);
		return acceptTopLevelBlock(asTlb, av);
	case Import:
		auto asImport = cast(ir.Import) n;
		assert(asImport !is null);
		return acceptImport(asImport, av);
	case Variable:
		return acceptVariable(cast(ir.Variable) n, av);
	case FunctionParam:
		auto fp = cast(ir.FunctionParam) n;
		assert(fp !is null);
		return acceptFunctionParam(fp, av);
	case Unittest:
		return acceptUnittest(cast(ir.Unittest) n, av);
	case Class:
		auto asClass = cast(ir.Class) n;
		assert(asClass !is null);
		return acceptClass(asClass, av);
	case Interface:
		auto asInterface = cast(ir._Interface) n;
		assert(asInterface !is null);
		return acceptInterface(asInterface, av);
	case Struct:
		return acceptStruct(cast(ir.Struct) n, av);
	case Union:
		return acceptUnion(cast(ir.Union) n, av);
	case Enum:
		auto asEnum = cast(ir.Enum) n;
		assert(asEnum !is null);
		return acceptEnum(asEnum, av);
	case Attribute:
		auto asAttribute = cast(ir.Attribute) n;
		assert(asAttribute !is null);
		return acceptAttribute(asAttribute, av);
	case StaticAssert:
		auto asStaticAssert = cast(ir.StaticAssert) n;
		assert(asStaticAssert !is null);
		return acceptStaticAssert(asStaticAssert, av);
	case EmptyTopLevel:
		auto asEmpty = cast(ir.EmptyTopLevel) n;
		assert(asEmpty !is null);
		return av.visit(asEmpty);
	case MixinFunction:
		auto asMf = cast(ir.MixinFunction) n;
		assert(asMf !is null);
		return acceptMixinFunction(asMf, av);
	case MixinTemplate:
		auto asMt = cast(ir.MixinTemplate) n;
		assert(asMt !is null);
		return acceptMixinTemplate(asMt, av);
	case ConditionTopLevel:
		auto asCtl = cast(ir.ConditionTopLevel) n;
		assert(asCtl !is null);
		return acceptConditionTopLevel(asCtl, av);
	case UserAttribute:
		auto asUi = cast(ir.UserAttribute) n;
		assert(asUi !is null);
		return acceptUserAttribute(asUi, av);
	case Condition:
		auto asCondition = cast(ir.Condition) n;
		assert(asCondition !is null);
		return acceptCondition(asCondition, av);
	case QualifiedName:
		auto asQname = cast(ir.QualifiedName) n;
		assert(asQname !is null);
		return av.visit(asQname);
	case Identifier:
		auto asName = cast(ir.Identifier) n;
		assert(asName !is null);
		return av.visit(asName);

	/*
	 * Expressions.
	 */
	case Constant:
	case IdentifierExp:
	case Postfix:
	case Unary:
	case BinOp:
	case Ternary:
	case ArrayLiteral:
	case AssocArray:
	case Assert:
	case StringImport:
	case Typeid:
	case IsExp:
	case FunctionLiteral:
	case ExpReference:
	case StructLiteral:
	case ClassLiteral:
	case TraitsExp:
	case TypeExp:
	case TemplateInstanceExp:
	case StatementExp:
	case TokenExp:
	case VaArgExp:
		throw panic(n.location, "can not visit expressions");

	/*
	 * Statements.
	 */
	case ExpStatement:
		return acceptExpStatement(cast(ir.ExpStatement) n, av);
	case ReturnStatement:
		return acceptReturnStatement(cast(ir.ReturnStatement) n, av);
	case BlockStatement:
		return acceptBlockStatement(cast(ir.BlockStatement) n, av);
	case AsmStatement:
		return acceptAsmStatement(cast(ir.AsmStatement) n, av);
	case IfStatement:
		return acceptIfStatement(cast(ir.IfStatement) n, av);
	case WhileStatement:
		return acceptWhileStatement(cast(ir.WhileStatement) n, av);
	case DoStatement:
		return acceptDoStatement(cast(ir.DoStatement) n, av);
	case ForStatement:
		return acceptForStatement(cast(ir.ForStatement) n, av);
	case ForeachStatement:
		return acceptForeachStatement(cast(ir.ForeachStatement) n, av);
	case LabelStatement:
		return acceptLabelStatement(cast(ir.LabelStatement) n, av);
	case SwitchStatement:
		return acceptSwitchStatement(cast(ir.SwitchStatement) n, av);
	case SwitchCase:
		auto sc = cast(ir.SwitchCase) n;
		assert(sc !is null);
		return acceptSwitchCase(sc, av);
	case ContinueStatement:
		auto asCont = cast(ir.ContinueStatement) n;
		assert(asCont !is null);
		return av.visit(asCont);
	case BreakStatement:
		auto asBreak = cast(ir.BreakStatement) n;
		assert(asBreak !is null);
		return av.visit(asBreak);
	case GotoStatement:
		return acceptGotoStatement(cast(ir.GotoStatement) n, av);
	case WithStatement:
		return acceptWithStatement(cast(ir.WithStatement) n, av);
	case SynchronizedStatement:
		return acceptSynchronizedStatement(cast(ir.SynchronizedStatement) n, av);
	case TryStatement:
		auto asTry = cast(ir.TryStatement) n;
		assert(asTry !is null);
		return acceptTryStatement(asTry, av);
	case ThrowStatement:
		auto asThrow = cast(ir.ThrowStatement) n;
		assert(asThrow !is null);
		return acceptThrowStatement(asThrow, av);
	case ScopeStatement:
		auto asScope = cast(ir.ScopeStatement) n;
		assert(asScope !is null);
		return acceptScopeStatement(asScope, av);
	case PragmaStatement:
		auto asPragma = cast(ir.PragmaStatement) n;
		assert(asPragma !is null);
		return acceptPragmaStatement(asPragma, av);
	case EmptyStatement:
		auto asEmpty = cast(ir.EmptyStatement) n;
		assert(asEmpty !is null);
		return av.visit(asEmpty);
	case ConditionStatement:
		auto asCs = cast(ir.ConditionStatement) n;
		assert(asCs !is null);
		return acceptConditionStatement(asCs, av);
	case MixinStatement:
		auto asMs = cast(ir.MixinStatement) n;
		assert(asMs !is null);
		return acceptMixinStatement(asMs, av);
	case AssertStatement:
		auto as = cast(ir.AssertStatement) n;
		assert(as !is null);
		return acceptAssertStatement(as, av);

	/*
	 * Declarations.
	 */
	case Function:
		return acceptFunction(cast(ir.Function) n, av);
	case PrimitiveType:
		return av.visit(cast(ir.PrimitiveType) n);
	case TypeReference:
		auto asUser = cast(ir.TypeReference) n;
		assert(asUser !is null);
		return av.visit(asUser);
	case PointerType:
		return acceptPointerType(cast(ir.PointerType) n, av);
	case ArrayType:
		return acceptArrayType(cast(ir.ArrayType) n, av);
	case StaticArrayType:
		return acceptStaticArrayType(cast(ir.StaticArrayType) n, av);
	case AAType:
		return acceptAAType(cast(ir.AAType) n, av);
	case FunctionType:
		return acceptFunctionType(cast(ir.FunctionType) n, av);
	case DelegateType:
		return acceptDelegateType(cast(ir.DelegateType) n, av);
	case StorageType:
		return acceptStorageType(cast(ir.StorageType) n, av);
	case Alias:
		return acceptAlias(cast(ir.Alias) n, av);
	case TypeOf:
		auto typeOf = cast(ir.TypeOf) n;
		assert(typeOf !is null);
		return acceptTypeOf(typeOf, av);
	case NullType:
		auto nt = cast(ir.NullType) n;
		assert(nt !is null);
		return av.visit(nt);
	case EnumDeclaration:
		auto ed = cast(ir.EnumDeclaration) n;
		assert(ed !is null);
		return acceptEnumDeclaration(ed, av);

	/*
	 * Failure fall through.
	 */
	case Invalid:
	case NonVisiting:
	case FunctionDecl:
	case FunctionBody:
	case AAPair:
	case FunctionSetType:
	case FunctionSet:
	case Comma:
		throw panicUnhandled(n, to!string(n.nodeType));
	}
}

Visitor.Status acceptExp(ref ir.Exp exp, Visitor av)
{
	auto status = av.debugVisitNode(exp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		return acceptConstant(exp, cast(ir.Constant)exp, av);
	case IdentifierExp:
		return acceptIdentifierExp(exp, cast(ir.IdentifierExp)exp, av);
	case Postfix:
		return acceptPostfix(exp, cast(ir.Postfix)exp, av);
	case Unary:
		return acceptUnary(exp, cast(ir.Unary)exp, av);
	case BinOp:
		return acceptBinOp(exp, cast(ir.BinOp)exp, av);
	case Ternary:
		return acceptTernary(exp, cast(ir.Ternary)exp, av);
	case ArrayLiteral:
		return acceptArrayLiteral(exp, cast(ir.ArrayLiteral)exp, av);
	case AssocArray:
		return acceptAssocArray(exp, cast(ir.AssocArray)exp, av);
	case Assert:
		return acceptAssert(exp, cast(ir.Assert)exp, av);
	case StringImport:
		return acceptStringImport(exp, cast(ir.StringImport)exp, av);
	case Typeid:
		return acceptTypeid(exp, cast(ir.Typeid)exp, av);
	case IsExp:
		return acceptIsExp(exp, cast(ir.IsExp)exp, av);
	case FunctionLiteral:
		return acceptFunctionLiteral(exp, cast(ir.FunctionLiteral)exp, av);
	case ExpReference:
		return acceptExpReference(exp, cast(ir.ExpReference)exp, av);
	case StructLiteral:
		return acceptStructLiteral(exp, cast(ir.StructLiteral)exp, av);
	case ClassLiteral:
		return acceptClassLiteral(exp, cast(ir.ClassLiteral)exp, av);
	case TraitsExp:
		return acceptTraitsExp(exp, cast(ir.TraitsExp)exp, av);
	case TokenExp:
		return acceptTokenExp(exp, cast(ir.TokenExp)exp, av);
	case TypeExp:
		return acceptTypeExp(exp, cast(ir.TypeExp)exp, av);
	case TemplateInstanceExp:
		return acceptTemplateInstanceExp(exp, cast(ir.TemplateInstanceExp)exp, av);
	case StatementExp:
		return acceptStatementExp(exp, cast(ir.StatementExp)exp, av);
	case VaArgExp:
		return acceptVaArgExp(exp, cast(ir.VaArgExp)exp, av);
	default:
		throw panicUnhandled(exp, to!string(exp.nodeType));
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

	// Use a for in lieu of a foreach so that all nodes will be visited if a Visitor modifies it.
	for (size_t i = 0; i < tlb.nodes.length; ++i) {
		auto n = tlb.nodes[i];
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
		status = acceptExp(d.assign, av);
		if (status == VisitorStop) {
			return status;
		}
	}

	return av.leave(d);
}

Visitor.Status acceptFunctionParam(ir.FunctionParam fp, Visitor av)
{
	auto status = av.enter(fp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (fp.assign !is null) {
		status = accept(fp.assign, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(fp);
}

Visitor.Status acceptUnittest(ir.Unittest u, Visitor av)
{
	auto status = av.enter(u);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (u._body !is null) {
		accept(u._body, av);
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

Visitor.Status acceptUnion(ir.Union u, Visitor av)
{
	auto status = av.enter(u);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(u.members, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(u);
}

Visitor.Status acceptEnum(ir.Enum e, Visitor av)
{
	auto status = av.enter(e);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (member; e.members) {
		status = accept(member, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	status = accept(e.base, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(e);
}

Visitor.Status acceptStaticAssert(ir.StaticAssert sa, Visitor av)
{
	auto status = av.enter(sa);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = acceptExp(sa.exp, av);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (sa.message !is null) {
		status = acceptExp(sa.message, av);
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

Visitor.Status acceptMixinFunction(ir.MixinFunction mf, Visitor av)
{
	auto status = av.enter(mf);
	if (status == VisitorStop) {
		return status;
	}

	// Raw members not visited.

	return av.leave(mf);
}

Visitor.Status acceptMixinTemplate(ir.MixinTemplate mt, Visitor av)
{
	auto status = av.enter(mt);
	if (status == VisitorStop) {
		return status;
	}

	// Raw members not visited.

	return av.leave(mt);
}

Visitor.Status acceptUserAttribute(ir.UserAttribute ui, Visitor av)
{
	auto status = av.enter(ui);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (field; ui.fields) {
		status = accept(field, av);
		if (status == VisitorStop) {
			return VisitorStop;
		} else if (status == VisitorContinue) {
			continue;
		}
	}

	if (ui.layoutClass !is null) {
		status = accept(ui.layoutClass, av);
		if (status != VisitorContinue) {
			return parentContinue(status);
		}
	}

	return av.leave(ui);
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

	if (attr.members !is null) foreach (toplevel; attr.members.nodes) {
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

	if (a.type !is null) {
		status = accept(a.type, av);
		if (status == VisitorStop) {
			return status;
		}
	}

	if (a.id !is null) {
		status = accept(a.id, av);
		if (status == VisitorStop) {
			return status;
		}
	}

	return av.leave(a);
}

Visitor.Status acceptTypeOf(ir.TypeOf typeOf, Visitor av)
{
	auto status = av.enter(typeOf);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = acceptExp(typeOf.exp, av);
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

	foreach (type; fn.params) {
		status = accept(type, av);
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
	foreach (type; fn.params) {
		status = accept(type, av);
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

	if (fn.type !is null) {
		status = accept(fn.type, av);
		if (status == VisitorStop)
			return status;
	}

	if (fn.thisHiddenParameter !is null) {
		status = accept(fn.thisHiddenParameter, av);
		if (status == VisitorStop)
			return status;
	}

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

Visitor.Status acceptEnumDeclaration(ir.EnumDeclaration ed, Visitor av)
{
	auto status = av.enter(ed);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (ed.type !is null && ed.type.nodeType != ir.NodeType.Enum) {
		status = accept(ed.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (ed.assign !is null) {
		status = acceptExp(ed.assign, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(ed);
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

	status = acceptExp(e.exp, av);
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
		status = acceptExp(ret.exp, av);
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

	// Use a for in lieu of a foreach so that all nodes will be visited if a Visitor modifies it.
	auto statements = b.statements;
	for (int i = 0; i < statements.length; ++i) {
		status = accept(statements[i], av);
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

	status = acceptExp(i.exp, av);
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

	status = acceptExp(w.condition, av);
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

	status = acceptExp(d.condition, av);
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
	foreach (ref i; f.initExps) {
		acceptExp(i, av);
	}

	if (f.test !is null) {
		acceptExp(f.test, av);
	}

	if (f.block !is null) {
		accept(f.block, av);
	}

	foreach (ref increment; f.increments) {
		acceptExp(increment, av);
	}

	return av.leave(f);
}

Visitor.Status acceptForeachStatement(ir.ForeachStatement fes, Visitor av)
{
	auto status = av.enter(fes);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (v; fes.itervars) {
		status = accept(v, av);
		if (status == VisitorContinueParent) {
			continue;
		} else if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (fes.beginIntegerRange !is null) {
		status = acceptExp(fes.beginIntegerRange, av);
		if (status != VisitorContinue) {
			return parentContinue(status);
		}
	}
	if (fes.endIntegerRange !is null) {
		status = acceptExp(fes.endIntegerRange, av);
		if (status != VisitorContinue) {
			return parentContinue(status);
		}
	}
	if (fes.aggregate !is null) {
		status = acceptExp(fes.aggregate, av);
		if (status != VisitorContinue) {
			return parentContinue(status);
		}
	}

	status = accept(fes.block, av);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	return av.leave(fes);
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

	status = acceptExp(ss.condition, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	foreach (i, _case; ss.cases) {
		status = accept(_case, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(ss);
}

Visitor.Status acceptSwitchCase(ir.SwitchCase sc, Visitor av)
{
	auto status = av.enter(sc);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (sc.firstExp !is null) {
		status = acceptExp(sc.firstExp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}
	if (sc.secondExp !is null) {
		status = acceptExp(sc.secondExp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}
	foreach (ref exp; sc.exps) {
		status = acceptExp(exp, av);
		if (status == VisitorContinueParent) {
			continue;
		} else if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	status = accept(sc.statements, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(sc);
}

Visitor.Status acceptGotoStatement(ir.GotoStatement gs, Visitor av)
{
	auto status = av.enter(gs);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (gs.exp !is null) {
		status = acceptExp(gs.exp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(gs);
}

Visitor.Status acceptWithStatement(ir.WithStatement ws, Visitor av)
{
	auto status = av.enter(ws);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	acceptExp(ws.exp, av);
	accept(ws.block, av);

	return av.leave(ws);
}

Visitor.Status acceptSynchronizedStatement(ir.SynchronizedStatement ss, Visitor av)
{
	auto status = av.enter(ss);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	accept(ss.block, av);

	return av.leave(ss);
}

Visitor.Status acceptTryStatement(ir.TryStatement ts, Visitor av)
{
	auto status = av.enter(ts);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(ts.tryBlock, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	foreach (i, v; ts.catchVars) {
		status = accept(ts.catchBlocks[i], av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (ts.catchAll !is null) {
		status = accept(ts.catchAll, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}


	if (ts.finallyBlock !is null) {
		status = accept(ts.finallyBlock, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(ts);
}

Visitor.Status acceptThrowStatement(ir.ThrowStatement ts, Visitor av)
{
	auto status = av.enter(ts);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = acceptExp(ts.exp, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(ts);
}

Visitor.Status acceptScopeStatement(ir.ScopeStatement ss, Visitor av)
{
	auto status = av.enter(ss);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(ss.block, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(ss);
}

Visitor.Status acceptPragmaStatement(ir.PragmaStatement ps, Visitor av)
{
	auto status = av.enter(ps);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(ps.block, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

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

Visitor.Status acceptAssertStatement(ir.AssertStatement as, Visitor av)
{
	auto status = av.enter(as);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = acceptExp(as.condition, av);
	if (status != VisitorContinue) {
		return status;
	}

	if (as.message !is null) {
		status = acceptExp(as.message, av);
		if (status != VisitorContinue) {
			return status;
		}
	}

	return av.leave(as);
}

Visitor.Status acceptMixinStatement(ir.MixinStatement ms, Visitor av)
{
	auto status = av.enter(ms);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (ms.id !is null) {
		status = accept(ms.id, av);
		if (status == VisitorStop)
			return VisitorStop;
	}

	if (ms.stringExp !is null) {
		status = acceptExp(ms.stringExp, av);
		if (status == VisitorStop)
			return VisitorStop;
	}

	if (ms.resolved !is null) {
		status = accept(ms.resolved, av);
		if (status == VisitorStop)
			return VisitorStop;
	}

	return av.leave(ms);
}


/*
 * Expressions.
 */

Visitor.Status acceptPostfix(ref ir.Exp exp, ir.Postfix postfix, Visitor av)
{
	auto status = av.enter(exp, postfix);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is postfix) {
		return acceptExp(exp, av);
	}

	if (postfix.child !is null) {
		status = acceptExp(postfix.child, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	foreach (ref arg; postfix.arguments) {
		status = acceptExp(arg, av);
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

	return av.leave(exp, postfix);
}

Visitor.Status acceptUnary(ref ir.Exp exp, ir.Unary unary, Visitor av)
{
	auto status = av.enter(exp, unary);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is unary) {
		return acceptExp(exp, av);
	}

	if (unary.type !is null) {
		status = accept(unary.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (unary.value !is null) {
		status = acceptExp(unary.value, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	foreach (ref arg; unary.argumentList) {
		status = acceptExp(arg, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, unary);
}

Visitor.Status acceptBinOp(ref ir.Exp exp, ir.BinOp binop, Visitor av)
{
	auto status = av.enter(exp, binop);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is binop) {
		return acceptExp(exp, av);
	}

	status = acceptExp(binop.left, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(binop.right, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, binop);
}

Visitor.Status acceptTernary(ref ir.Exp exp, ir.Ternary ternary, Visitor av)
{
	auto status = av.enter(exp, ternary);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is ternary) {
		return acceptExp(exp, av);
	}

	status = acceptExp(ternary.condition, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(ternary.ifTrue, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(ternary.ifFalse, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, ternary);
}

Visitor.Status acceptArrayLiteral(ref ir.Exp exp, ir.ArrayLiteral array, Visitor av)
{
	auto status = av.enter(exp, array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is array) {
		return acceptExp(exp, av);
	}

	if (array.type !is null) {
		status = accept(array.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	foreach (ref childExp; array.values) {
		status = acceptExp(childExp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, array);
}

Visitor.Status acceptAssocArray(ref ir.Exp exp, ir.AssocArray array, Visitor av)
{
	auto status = av.enter(exp, array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is array) {
		return acceptExp(exp, av);
	}

	foreach (ref pair; array.pairs) {
		status = acceptExp(pair.key, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
		status = acceptExp(pair.value, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, array);
}

Visitor.Status acceptAssert(ref ir.Exp exp, ir.Assert _assert, Visitor av)
{
	auto status = av.enter(exp, _assert);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is _assert) {
		return acceptExp(exp, av);
	}

	status = acceptExp(_assert.condition, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	if (_assert.message !is null) {
		status = acceptExp(_assert.message, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, _assert);
}

Visitor.Status acceptStringImport(ref ir.Exp exp, ir.StringImport strimport, Visitor av)
{
	auto status = av.enter(exp, strimport);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is strimport) {
		return acceptExp(exp, av);
	}

	status = acceptExp(strimport.filename, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, strimport);
}

Visitor.Status acceptTypeid(ref ir.Exp exp, ir.Typeid ti, Visitor av)
{
	auto status = av.enter(exp, ti);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is ti) {
		return acceptExp(exp, av);
	}

	if (ti.ident.length == 0) {
		if (ti.exp !is null) {
			status = acceptExp(ti.exp, av);
		} else {
			status = accept(ti.type, av);
		}
	}
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, ti);
}

Visitor.Status acceptIsExp(ref ir.Exp exp, ir.IsExp isExp, Visitor av)
{
	auto status = av.enter(exp, isExp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is isExp) {
		return acceptExp(exp, av);
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

	return av.leave(exp, isExp);
}

Visitor.Status acceptFunctionLiteral(ref ir.Exp exp, ir.FunctionLiteral functionLiteral, Visitor av)
{
	auto status = av.enter(exp, functionLiteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is functionLiteral) {
		return acceptExp(exp, av);
	}

	if (functionLiteral.block !is null) {
		accept(functionLiteral.block, av);
	}

	return av.leave(exp, functionLiteral);
}

Visitor.Status acceptStructLiteral(ref ir.Exp exp, ir.StructLiteral sliteral, Visitor av)
{
	auto status = av.enter(exp, sliteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is sliteral) {
		return acceptExp(exp, av);
	}

	foreach (ref sexp; sliteral.exps) {
		status = acceptExp(sexp, av);
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

	return av.leave(exp, sliteral);
}

Visitor.Status acceptClassLiteral(ref ir.Exp exp, ir.ClassLiteral cliteral, Visitor av)
{
	auto status = av.enter(exp, cliteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is cliteral) {
		return acceptExp(exp, av);
	}

	foreach (ref sexp; cliteral.exps) {
		status = acceptExp(sexp, av);
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

	return av.leave(exp, cliteral);
}

Visitor.Status acceptTypeExp(ref ir.Exp exp, ir.TypeExp texp, Visitor av)
{
	auto status = av.enter(exp, texp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(texp.type, av);
	if (status != VisitorContinue) {
		return status;
	}

	return av.leave(exp, texp);
}

Visitor.Status acceptTemplateInstanceExp(ref ir.Exp exp, ir.TemplateInstanceExp texp, Visitor av)
{
	auto status = av.enter(exp, texp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (type; texp.types) {
		status = accept(type, av);
		if (status == VisitorContinueParent) {
			continue;
		} else if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, texp);
}

Visitor.Status acceptStatementExp(ref ir.Exp exp, ir.StatementExp state, Visitor av)
{
	auto status = av.enter(exp, state);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (stat; state.statements) {
		status = accept(stat, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (state.exp !is null) {
		status = acceptExp(state.exp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(exp, state);
}

Visitor.Status acceptTraitsExp(ref ir.Exp exp, ir.TraitsExp texp, Visitor av)
{
	return av.visit(exp, texp);
}

Visitor.Status acceptTokenExp(ref ir.Exp exp, ir.TokenExp fexp, Visitor av)
{
	return av.visit(exp, fexp);
}

Visitor.Status acceptVaArgExp(ref ir.Exp exp, ir.VaArgExp vaexp, Visitor av)
{
	auto status = av.enter(exp, vaexp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(vaexp.type, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(vaexp.arg, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, vaexp);
}

Visitor.Status acceptExpReference(ref ir.Exp exp, ir.ExpReference expref, Visitor av)
{
	return av.visit(exp, expref);
}

Visitor.Status acceptConstant(ref ir.Exp exp, ir.Constant constant, Visitor av)
{
	auto status = av.enter(exp, constant);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is constant) {
		return acceptExp(exp, av);
	}

	status = accept(constant.type, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(exp, constant);
}

Visitor.Status acceptIdentifierExp(ref ir.Exp exp, ir.IdentifierExp identifier, Visitor av)
{
	return av.visit(exp, identifier);
}
