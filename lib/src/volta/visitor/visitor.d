/*#D*/
// Copyright 2012-2017, Bernard Helyer.
// Copyright 2012-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volta.visitor.visitor;

import watt.text.format : format;
import watt.text.sink : StringSink;

import ir = volta.ir;


/**
 * Base class for all Visitors.
 */
abstract class Visitor
{
public:
	enum Status {
		Stop,
		Continue,
		ContinueParent,
	}

	alias Stop = Status.Stop;
	alias Continue = Status.Continue;
	alias ContinueParent = Status.ContinueParent;


public abstract:

	/**
	 * Called on a internal visiting error.
	 */
	Status visitingError(ir.Node n, string msg);

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
	Status enter(ir.Condition c);
	Status leave(ir.Condition c);
	Status enter(ir.ConditionTopLevel ctl);
	Status leave(ir.ConditionTopLevel ctl);
	Status enter(ir.MixinFunction mf);
	Status leave(ir.MixinFunction mf);
	Status enter(ir.MixinTemplate mt);
	Status leave(ir.MixinTemplate mt);

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
	Status enter(ir.AmbiguousArrayType array);
	Status leave(ir.AmbiguousArrayType array);
	Status enter(ir.FunctionType func);
	Status leave(ir.FunctionType func);
	Status enter(ir.DelegateType func);
	Status leave(ir.DelegateType func);
	Status enter(ir.Function func);
	Status leave(ir.Function func);
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
	Status enter(ir.AliasStaticIf);
	Status leave(ir.AliasStaticIf);

	Status visit(ir.PrimitiveType it);
	Status visit(ir.TypeReference tr);
	Status visit(ir.NullType nt);
	Status visit(ir.AutoType at);
	Status visit(ir.NoType at);

	/*
	 * Template Nodes.
	 */
	Status enter(ir.TemplateInstance ti);
	Status leave(ir.TemplateInstance ti);
	Status visit(ir.TemplateDefinition td);


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
	Visitor.Status enter(ref ir.Exp, ir.UnionLiteral);
	Visitor.Status leave(ref ir.Exp, ir.UnionLiteral);
	Visitor.Status enter(ref ir.Exp, ir.ClassLiteral);
	Visitor.Status leave(ref ir.Exp, ir.ClassLiteral);
	Visitor.Status enter(ref ir.Exp, ir.Constant);
	Visitor.Status leave(ref ir.Exp, ir.Constant);
	Visitor.Status enter(ref ir.Exp, ir.TypeExp);
	Visitor.Status leave(ref ir.Exp, ir.TypeExp);
	Visitor.Status enter(ref ir.Exp, ir.StatementExp);
	Visitor.Status leave(ref ir.Exp, ir.StatementExp);
	Visitor.Status enter(ref ir.Exp, ir.VaArgExp);
	Visitor.Status leave(ref ir.Exp, ir.VaArgExp);
	Visitor.Status enter(ref ir.Exp, ir.PropertyExp);
	Visitor.Status leave(ref ir.Exp, ir.PropertyExp);
	Visitor.Status enter(ref ir.Exp, ir.BuiltinExp);
	Visitor.Status leave(ref ir.Exp, ir.BuiltinExp);
	Visitor.Status enter(ref ir.Exp, ir.AccessExp);
	Visitor.Status leave(ref ir.Exp, ir.AccessExp);
	Visitor.Status enter(ref ir.Exp, ir.RunExp);
	Visitor.Status leave(ref ir.Exp, ir.RunExp);
	Visitor.Status enter(ref ir.Exp, ir.ComposableString);
	Visitor.Status leave(ref ir.Exp, ir.ComposableString);

	Visitor.Status visit(ref ir.Exp, ir.IdentifierExp);
	Visitor.Status visit(ref ir.Exp, ir.ExpReference);
	Visitor.Status visit(ref ir.Exp, ir.TokenExp);
	Visitor.Status visit(ref ir.Exp, ir.StoreExp);
}

alias VisitorStop = Visitor.Status.Stop;
alias VisitorContinue = Visitor.Status.Continue;
alias VisitorContinueParent = Visitor.Status.ContinueParent;

//! A visitor that does nothing.
abstract class NullVisitor : Visitor
{
public override:
	/*
	 * Special.
	 */
	Status visitingError(ir.Node n, string msg) { return Stop; }

	/*
	 * Base.
	 */
	Status enter(ir.Module m) { return Continue; }
	Status leave(ir.Module m) { return Continue; }
	Status enter(ir.TopLevelBlock tlb) { return Continue; }
	Status leave(ir.TopLevelBlock tlb) { return Continue; } 
	Status enter(ir.Import i) { return Continue; }
	Status leave(ir.Import i) { return Continue; }
	Status enter(ir.Unittest u) { return Continue; }
	Status leave(ir.Unittest u) { return Continue; }
	Status enter(ir.Class c) { return Continue; }
	Status leave(ir.Class c) { return Continue; }
	Status enter(ir._Interface i) { return Continue; }
	Status leave(ir._Interface i) { return Continue; }
	Status enter(ir.Union u) { return Continue; }
	Status leave(ir.Union u) { return Continue; }
	Status enter(ir.Struct s) { return Continue; }
	Status leave(ir.Struct s) { return Continue; }
	Status enter(ir.Variable d) { return Continue; }
	Status leave(ir.Variable d) { return Continue; }
	Status enter(ir.FunctionParam fp) { return Continue; }
	Status leave(ir.FunctionParam fp) { return Continue; }
	Status enter(ir.Enum e) { return Continue; }
	Status leave(ir.Enum e) { return Continue; }
	Status enter(ir.Condition c) { return Continue; }
	Status leave(ir.Condition c) { return Continue; }
	Status enter(ir.ConditionTopLevel ctl) { return Continue; }
	Status leave(ir.ConditionTopLevel ctl) { return Continue; }
	Status enter(ir.MixinFunction mf) { return Continue; }
	Status leave(ir.MixinFunction mf) { return Continue; }
	Status enter(ir.MixinTemplate mt) { return Continue; }
	Status leave(ir.MixinTemplate mt) { return Continue; }
	Status visit(ir.QualifiedName qname) { return Continue; }
	Status visit(ir.Identifier name) { return Continue; }

	/*
	 * Statement Nodes.
	 */
	Status enter(ir.ExpStatement e) { return Continue; }
	Status leave(ir.ExpStatement e) { return Continue; }
	Status enter(ir.ReturnStatement ret) { return Continue; }
	Status leave(ir.ReturnStatement ret) { return Continue; }
	Status enter(ir.BlockStatement b) { return Continue; }
	Status leave(ir.BlockStatement b) { return Continue; }
	Status enter(ir.AsmStatement a) { return Continue; }
	Status leave(ir.AsmStatement a) { return Continue; }
	Status enter(ir.IfStatement i) { return Continue; }
	Status leave(ir.IfStatement i) { return Continue; }
	Status enter(ir.WhileStatement w) { return Continue; }
	Status leave(ir.WhileStatement w) { return Continue; }
	Status enter(ir.DoStatement d) { return Continue; }
	Status leave(ir.DoStatement d) { return Continue; }
	Status enter(ir.ForStatement f) { return Continue; }
	Status leave(ir.ForStatement f) { return Continue; }
	Status enter(ir.ForeachStatement fes) { return Continue; }
	Status leave(ir.ForeachStatement fes) { return Continue; }
	Status enter(ir.LabelStatement ls) { return Continue; }
	Status leave(ir.LabelStatement ls) { return Continue; }
	Status enter(ir.SwitchStatement ss) { return Continue; }
	Status leave(ir.SwitchStatement ss) { return Continue; }
	Status enter(ir.SwitchCase c) { return Continue; }
	Status leave(ir.SwitchCase c) { return Continue; }
	Status enter(ir.GotoStatement gs) { return Continue; }
	Status leave(ir.GotoStatement gs) { return Continue; }
	Status enter(ir.WithStatement ws) { return Continue; }
	Status leave(ir.WithStatement ws) { return Continue; }
	Status enter(ir.SynchronizedStatement ss) { return Continue; }
	Status leave(ir.SynchronizedStatement ss) { return Continue; }
	Status enter(ir.TryStatement ts) { return Continue; }
	Status leave(ir.TryStatement ts) { return Continue; }
	Status enter(ir.ThrowStatement ts) { return Continue; }
	Status leave(ir.ThrowStatement ts) { return Continue; }
	Status enter(ir.ScopeStatement ss) { return Continue; }
	Status leave(ir.ScopeStatement ss) { return Continue; }
	Status enter(ir.PragmaStatement ps) { return Continue; }
	Status leave(ir.PragmaStatement ps) { return Continue; }
	Status enter(ir.ConditionStatement cs) { return Continue; }
	Status leave(ir.ConditionStatement cs) { return Continue; }
	Status enter(ir.MixinStatement ms) { return Continue; }
	Status leave(ir.MixinStatement ms) { return Continue; }
	Status enter(ir.AssertStatement as) { return Continue; }
	Status leave(ir.AssertStatement as) { return Continue; }
	
	Status visit(ir.ContinueStatement cs) { return Continue; }
	Status visit(ir.BreakStatement bs) { return Continue; }

	/*
	 * Declaration
	 */
	Status enter(ir.PointerType pointer) { return Continue; }
	Status leave(ir.PointerType pointer) { return Continue; }
	Status enter(ir.ArrayType array) { return Continue; }
	Status leave(ir.ArrayType array) { return Continue; }
	Status enter(ir.StaticArrayType array) { return Continue; }
	Status leave(ir.StaticArrayType array) { return Continue; }
	Status enter(ir.AAType array) { return Continue; }
	Status leave(ir.AAType array) { return Continue; }
	Status enter(ir.AmbiguousArrayType array) { return Continue; }
	Status leave(ir.AmbiguousArrayType array) { return Continue; }
	Status enter(ir.FunctionType func) { return Continue; }
	Status leave(ir.FunctionType func) { return Continue; }
	Status enter(ir.DelegateType func) { return Continue; }
	Status leave(ir.DelegateType func) { return Continue; }
	Status enter(ir.Function func) { return Continue; }
	Status leave(ir.Function func) { return Continue; }
	Status enter(ir.StorageType type) { return Continue; }
	Status leave(ir.StorageType type) { return Continue; }
	Status enter(ir.Attribute attr) { return Continue; }
	Status leave(ir.Attribute attr) { return Continue; }
	Status enter(ir.Alias a) { return Continue; }
	Status leave(ir.Alias a) { return Continue; }
	Status enter(ir.TypeOf to) { return Continue; }
	Status leave(ir.TypeOf to) { return Continue; }
	Status enter(ir.EnumDeclaration ed) { return Continue; }
	Status leave(ir.EnumDeclaration ed) { return Continue; }
	Status enter(ir.AliasStaticIf asi) { return Continue; }
	Status leave(ir.AliasStaticIf asi) { return Continue; }

	/*
	 * Template Nodes.
	 */
	Status enter(ir.TemplateInstance ti) { return Continue; }
	Status leave(ir.TemplateInstance ti) { return Continue; }
	Status visit(ir.TemplateDefinition td) { return Continue; }

	Status visit(ir.PrimitiveType it) { return Continue; }
	Status visit(ir.TypeReference tr) { return Continue; }
	Status visit(ir.NullType nt) { return Continue; }
	Status visit(ir.AutoType at) { return Continue; }
	Status visit(ir.NoType at) { return Continue; }

	/*
	 * Expression Nodes.
	 */
	Status enter(ref ir.Exp, ir.Postfix) { return Continue; }
	Status leave(ref ir.Exp, ir.Postfix) { return Continue; }
	Status enter(ref ir.Exp, ir.Unary) { return Continue; }
	Status leave(ref ir.Exp, ir.Unary) { return Continue; }
	Status enter(ref ir.Exp, ir.BinOp) { return Continue; }
	Status leave(ref ir.Exp, ir.BinOp) { return Continue; }
	Status enter(ref ir.Exp, ir.Ternary) { return Continue; }
	Status leave(ref ir.Exp, ir.Ternary) { return Continue; }
	Status enter(ref ir.Exp, ir.ArrayLiteral) { return Continue; }
	Status leave(ref ir.Exp, ir.ArrayLiteral) { return Continue; }
	Status enter(ref ir.Exp, ir.AssocArray) { return Continue; }
	Status leave(ref ir.Exp, ir.AssocArray) { return Continue; }
	Status enter(ref ir.Exp, ir.Assert) { return Continue; }
	Status leave(ref ir.Exp, ir.Assert) { return Continue; }
	Status enter(ref ir.Exp, ir.StringImport) { return Continue; }
	Status leave(ref ir.Exp, ir.StringImport) { return Continue; }
	Status enter(ref ir.Exp, ir.Typeid) { return Continue; }
	Status leave(ref ir.Exp, ir.Typeid) { return Continue; }
	Status enter(ref ir.Exp, ir.IsExp) { return Continue; }
	Status leave(ref ir.Exp, ir.IsExp) { return Continue; }
	Status enter(ref ir.Exp, ir.FunctionLiteral) { return Continue; }
	Status leave(ref ir.Exp, ir.FunctionLiteral) { return Continue; }
	Status enter(ref ir.Exp, ir.StructLiteral) { return Continue; }
	Status leave(ref ir.Exp, ir.StructLiteral) { return Continue; }
	Status enter(ref ir.Exp, ir.UnionLiteral) { return Continue; }
	Status leave(ref ir.Exp, ir.UnionLiteral) { return Continue; }
	Status enter(ref ir.Exp, ir.ClassLiteral) { return Continue; }
	Status leave(ref ir.Exp, ir.ClassLiteral) { return Continue; }
	Status enter(ref ir.Exp, ir.Constant) { return Continue; }
	Status leave(ref ir.Exp, ir.Constant) { return Continue; }
	Status enter(ref ir.Exp, ir.TypeExp) { return Continue; }
	Status leave(ref ir.Exp, ir.TypeExp) { return Continue; }
	Status enter(ref ir.Exp, ir.StatementExp) { return Continue; }
	Status leave(ref ir.Exp, ir.StatementExp) { return Continue; }
	Status enter(ref ir.Exp, ir.VaArgExp) { return Continue; }
	Status leave(ref ir.Exp, ir.VaArgExp) { return Continue; }
	Status enter(ref ir.Exp, ir.PropertyExp) { return Continue; }
	Status leave(ref ir.Exp, ir.PropertyExp) { return Continue; }
	Status enter(ref ir.Exp, ir.BuiltinExp) { return Continue; }
	Status leave(ref ir.Exp, ir.BuiltinExp) { return Continue; }
	Status enter(ref ir.Exp, ir.AccessExp) { return Continue; }
	Status leave(ref ir.Exp, ir.AccessExp) { return Continue; }
	Status enter(ref ir.Exp, ir.RunExp) { return Continue; }
	Status leave(ref ir.Exp, ir.RunExp) { return Continue; }
	Status enter(ref ir.Exp, ir.ComposableString) { return Continue; }
	Status leave(ref ir.Exp, ir.ComposableString) { return Continue; }

	Status visit(ref ir.Exp, ir.ExpReference) { return Continue; }
	Status visit(ref ir.Exp, ir.IdentifierExp) { return Continue; }
	Status visit(ref ir.Exp, ir.TokenExp) { return Continue; }
	Status visit(ref ir.Exp, ir.StoreExp) { return Continue; }
}


/*!
 * Helper function that returns VistorContinue if @s is
 * VisitorContinueParent, used to abort a leaf node, but
 * not the whole tree.
 */
Visitor.Status parentContinue(Visitor.Status s)
{
	return s == VisitorContinueParent ? VisitorContinue : s;
}




Visitor.Status accept(ir.Node n, Visitor av)
out (result) {
	assert(result != VisitorContinueParent);
}
do {
	final switch (n.nodeType) with (ir.NodeType) {
	/*
	 * Top Levels.
	 */
	case Module:
		return acceptModule(n.toModuleFast(), av);
	case TopLevelBlock:
		return acceptTopLevelBlock(n.toTopLevelBlockFast(), av);
	case Import:
		return acceptImport(n.toImportFast(), av);
	case Variable:
		return acceptVariable(n.toVariableFast(), av);
	case FunctionParam:
		return acceptFunctionParam(n.toFunctionParamFast(), av);
	case Unittest:
		return acceptUnittest(n.toUnittestFast(), av);
	case Class:
		return acceptClass(n.toClassFast(), av);
	case Interface:
		return acceptInterface(n.toInterfaceFast(), av);
	case Struct:
		return acceptStruct(n.toStructFast(), av);
	case Union:
		return acceptUnion(n.toUnionFast(), av);
	case Enum:
		return acceptEnum(n.toEnumFast(), av);
	case Attribute:
		return acceptAttribute(n.toAttributeFast(), av);
	case MixinFunction:
		return acceptMixinFunction(n.toMixinFunctionFast(), av);
	case MixinTemplate:
		return acceptMixinTemplate(n.toMixinTemplateFast(), av);
	case ConditionTopLevel:
		return acceptConditionTopLevel(n.toConditionTopLevelFast(), av);
	case Condition:
		return acceptCondition(n.toConditionFast(), av);
	case QualifiedName:
		return av.visit(n.toQualifiedNameFast());
	case Identifier:
		return av.visit(n.toIdentifierFast());

	/*
	 * Expressions.
	 */
	case MergeNode:
		return av.visitingError(n, "can not visit MergeNode");

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
	case UnionLiteral:
	case ClassLiteral:
	case TypeExp:
	case StoreExp:
	case StatementExp:
	case TokenExp:
	case VaArgExp:
	case PropertyExp:
	case BuiltinExp:
	case AccessExp:
	case RunExp:
	case ComposableString:
		return av.visitingError(n, "can not visit expressions");

	/*
	 * Statements.
	 */
	case ExpStatement:
		return acceptExpStatement(n.toExpStatementFast(), av);
	case ReturnStatement:
		return acceptReturnStatement(n.toReturnStatementFast(), av);
	case BlockStatement:
		return acceptBlockStatement(n.toBlockStatementFast(), av);
	case AsmStatement:
		return acceptAsmStatement(n.toAsmStatementFast(), av);
	case IfStatement:
		return acceptIfStatement(n.toIfStatementFast(), av);
	case WhileStatement:
		return acceptWhileStatement(n.toWhileStatementFast(), av);
	case DoStatement:
		return acceptDoStatement(n.toDoStatementFast(), av);
	case ForStatement:
		return acceptForStatement(n.toForStatementFast(), av);
	case ForeachStatement:
		return acceptForeachStatement(n.toForeachStatementFast(), av);
	case LabelStatement:
		return acceptLabelStatement(n.toLabelStatementFast(), av);
	case SwitchStatement:
		return acceptSwitchStatement(n.toSwitchStatementFast(), av);
	case SwitchCase:
		return acceptSwitchCase(n.toSwitchCaseFast(), av);
	case ContinueStatement:
		return av.visit(n.toContinueStatementFast());
	case BreakStatement:
		return av.visit(n.toBreakStatementFast());
	case GotoStatement:
		return acceptGotoStatement(n.toGotoStatementFast(), av);
	case WithStatement:
		return acceptWithStatement(n.toWithStatementFast(), av);
	case SynchronizedStatement:
		return acceptSynchronizedStatement(n.toSynchronizedStatementFast(), av);
	case TryStatement:
		return acceptTryStatement(n.toTryStatementFast(), av);
	case ThrowStatement:
		return acceptThrowStatement(n.toThrowStatementFast(), av);
	case ScopeStatement:
		return acceptScopeStatement(n.toScopeStatementFast(), av);
	case PragmaStatement:
		return acceptPragmaStatement(n.toPragmaStatementFast(), av);
	case ConditionStatement:
		return acceptConditionStatement(n.toConditionStatementFast(), av);
	case MixinStatement:
		return acceptMixinStatement(n.toMixinStatementFast(), av);
	case AssertStatement:
		return acceptAssertStatement(n.toAssertStatementFast(), av);

	/*
	 * Declarations.
	 */
	case Function:
		return acceptFunction(n.toFunctionFast(), av);
	case PrimitiveType:
		return av.visit(n.toPrimitiveTypeFast());
	case TypeReference:
		return av.visit(n.toTypeReferenceFast());
	case PointerType:
		return acceptPointerType(n.toPointerTypeFast(), av);
	case ArrayType:
		return acceptArrayType(n.toArrayTypeFast(), av);
	case AmbiguousArrayType:
		return acceptAmbiguousArrayType(n.toAmbiguousArrayTypeFast(), av);
	case StaticArrayType:
		return acceptStaticArrayType(n.toStaticArrayTypeFast(), av);
	case AAType:
		return acceptAAType(n.toAATypeFast(), av);
	case FunctionType:
		return acceptFunctionType(n.toFunctionTypeFast(), av);
	case DelegateType:
		return acceptDelegateType(n.toDelegateTypeFast(), av);
	case StorageType:
		return acceptStorageType(n.toStorageTypeFast(), av);
	case Alias:
		return acceptAlias(n.toAliasFast(), av);
	case TypeOf:
		return acceptTypeOf(n.toTypeOfFast(), av);
	case NullType:
		return av.visit(n.toNullTypeFast());
	case EnumDeclaration:
		return acceptEnumDeclaration(n.toEnumDeclarationFast(), av);
	case AutoType:
		return av.visit(n.toAutoTypeFast());
	case NoType:
		return av.visit(n.toNoTypeFast());
	case AliasStaticIf:
		return acceptAliasStaticIf(n.toAliasStaticIfFast(), av);

	/*
	 * Templates
	 */
	case TemplateInstance:
		return acceptTemplateInstance(n.toTemplateInstanceFast(), av);
	case TemplateDefinition:
		return acceptTemplateDefinition(n.toTemplateDefinitionFast(), av);

	/*
	 * Failure fall through.
	 */
	case Invalid:
	case NonVisiting:
	case AAPair:
	case FunctionSetType:
	case FunctionSet:
		return av.visitingError(n, "unhandled in accept");
	}
}

Visitor.Status acceptExp(ref ir.Exp exp, Visitor av)
{
	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		return acceptConstant(/*#ref*/exp, exp.toConstantFast(), av);
	case IdentifierExp:
		return acceptIdentifierExp(/*#ref*/exp, exp.toIdentifierExpFast(), av);
	case Postfix:
		return acceptPostfix(/*#ref*/exp, exp.toPostfixFast(), av);
	case Unary:
		return acceptUnary(/*#ref*/exp, exp.toUnaryFast(), av);
	case BinOp:
		return acceptBinOp(/*#ref*/exp, exp.toBinOpFast(), av);
	case Ternary:
		return acceptTernary(/*#ref*/exp, exp.toTernaryFast(), av);
	case ArrayLiteral:
		return acceptArrayLiteral(/*#ref*/exp, exp.toArrayLiteralFast(), av);
	case AssocArray:
		return acceptAssocArray(/*#ref*/exp, exp.toAssocArrayFast(), av);
	case Assert:
		return acceptAssert(/*#ref*/exp, exp.toAssertFast(), av);
	case StringImport:
		return acceptStringImport(/*#ref*/exp, exp.toStringImportFast(), av);
	case Typeid:
		return acceptTypeid(/*#ref*/exp, exp.toTypeidFast(), av);
	case IsExp:
		return acceptIsExp(/*#ref*/exp, exp.toIsExpFast(), av);
	case FunctionLiteral:
		return acceptFunctionLiteral(/*#ref*/exp, exp.toFunctionLiteralFast(), av);
	case ExpReference:
		return acceptExpReference(/*#ref*/exp, exp.toExpReferenceFast(), av);
	case StructLiteral:
		return acceptStructLiteral(/*#ref*/exp, exp.toStructLiteralFast(), av);
	case UnionLiteral:
		return acceptUnionLiteral(/*#ref*/exp, exp.toUnionLiteralFast(), av);
	case ClassLiteral:
		return acceptClassLiteral(/*#ref*/exp, exp.toClassLiteralFast(), av);
	case TokenExp:
		return acceptTokenExp(/*#ref*/exp, exp.toTokenExpFast(), av);
	case TypeExp:
		return acceptTypeExp(/*#ref*/exp, exp.toTypeExpFast(), av);
	case StoreExp:
		return acceptStoreExp(/*#ref*/exp, exp.toStoreExpFast(), av);
	case StatementExp:
		return acceptStatementExp(/*#ref*/exp, exp.toStatementExpFast(), av);
	case VaArgExp:
		return acceptVaArgExp(/*#ref*/exp, exp.toVaArgExpFast(), av);
	case PropertyExp:
		return acceptPropertyExp(/*#ref*/exp, exp.toPropertyExpFast(), av);
	case BuiltinExp:
		return acceptBuiltinExp(/*#ref*/exp, exp.toBuiltinExpFast(), av);
	case AccessExp:
		return acceptAccessExp(/*#ref*/exp, exp.toAccessExpFast(), av);
	case RunExp:
		return acceptRunExp(/*#ref*/exp, exp.toRunExpFast(), av);
	case ComposableString:
		return acceptComposableString(/*#ref*/exp, exp.toComposableStringFast(), av);
	default:
		return av.visitingError(exp, "unhandled in acceptExp");
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
		status = acceptExp(/*#ref*/d.assign, av);
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

	if (c.members !is null) {
		status = accept(c.members, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(c);
}

Visitor.Status acceptInterface(ir._Interface i, Visitor av)
{
	auto status = av.enter(i);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (i.members !is null) {
		status = accept(i.members, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(i);
}

Visitor.Status acceptStruct(ir.Struct s, Visitor av)
{
	auto status = av.enter(s);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (s.members !is null) {
		status = accept(s.members, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}
	return av.leave(s);
}

Visitor.Status acceptUnion(ir.Union u, Visitor av)
{
	auto status = av.enter(u);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (u.members !is null) {
		status = accept(u.members, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
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

/*
 * Declarations.
 */

Visitor.Status acceptAttribute(ir.Attribute attr, Visitor av)
{
	auto status = av.enter(attr);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (attr.chain !is null) {
		status = accept(attr.chain, av);
		if (status != VisitorContinue) {
			return parentContinue(status);
		}
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

	status = acceptExp(/*#ref*/typeOf.exp, av);
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

Visitor.Status acceptAmbiguousArrayType(ir.AmbiguousArrayType array, Visitor av)
{
	auto status = av.enter(array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(array.base, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(/*#ref*/array.child, av);
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

Visitor.Status acceptFunctionType(ir.FunctionType func, Visitor av)
{
	auto status = av.enter(func);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(func.ret, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	foreach (type; func.params) {
		status = accept(type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(func);
}

Visitor.Status acceptDelegateType(ir.DelegateType func, Visitor av)
{
	auto status = av.enter(func);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(func.ret, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}
	foreach (type; func.params) {
		status = accept(type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(func);
}

Visitor.Status acceptFunction(ir.Function func, Visitor av)
{
	auto status = av.enter(func);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (func.type !is null) {
		status = accept(func.type, av);
		if (status == VisitorStop)
			return status;
	}

	if (func.thisHiddenParameter !is null) {
		status = accept(func.thisHiddenParameter, av);
		if (status == VisitorStop)
			return status;
	}

	if (func.nestedHiddenParameter !is null) {
		status = accept(func.nestedHiddenParameter, av);
		if (status == VisitorStop)
			return status;
	}

	if (func.parsedIn !is null) {
		status = accept(func.parsedIn, av);
		if (status == VisitorStop)
			return status;
	}

	if (func.parsedOut !is null) {
		status = accept(func.parsedOut, av);
		if (status == VisitorStop)
			return status;
	}

	if (func.parsedBody !is null) {
		status = accept(func.parsedBody, av);
		if (status == VisitorStop)
			return status;
	}

	return av.leave(func);
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
		status = acceptExp(/*#ref*/ed.assign, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(ed);
}

Visitor.Status acceptAliasStaticIf(ir.AliasStaticIf asi, Visitor av)
{
	auto status = av.enter(asi);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (ref condition; asi.conditions) {
		status = acceptExp(/*#ref*/condition, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	foreach (type; asi.types) {
		status = accept(type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(asi);
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

	status = acceptExp(/*#ref*/e.exp, av);
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
		status = acceptExp(/*#ref*/ret.exp, av);
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
	for (size_t i = 0; i < statements.length; ++i) {
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

	status = acceptExp(/*#ref*/i.exp, av);
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

	status = acceptExp(/*#ref*/w.condition, av);
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

	status = acceptExp(/*#ref*/d.condition, av);
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
		acceptExp(/*#ref*/i, av);
	}

	if (f.test !is null) {
		acceptExp(/*#ref*/f.test, av);
	}

	if (f.block !is null) {
		accept(f.block, av);
	}

	foreach (ref increment; f.increments) {
		acceptExp(/*#ref*/increment, av);
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
		status = acceptExp(/*#ref*/fes.beginIntegerRange, av);
		if (status != VisitorContinue) {
			return parentContinue(status);
		}
	}
	if (fes.endIntegerRange !is null) {
		status = acceptExp(/*#ref*/fes.endIntegerRange, av);
		if (status != VisitorContinue) {
			return parentContinue(status);
		}
	}
	if (fes.aggregate !is null) {
		status = acceptExp(/*#ref*/fes.aggregate, av);
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

	status = acceptExp(/*#ref*/ss.condition, av);
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
		status = acceptExp(/*#ref*/sc.firstExp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}
	if (sc.secondExp !is null) {
		status = acceptExp(/*#ref*/sc.secondExp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}
	foreach (ref exp; sc.exps) {
		status = acceptExp(/*#ref*/exp, av);
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
		status = acceptExp(/*#ref*/gs.exp, av);
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

	acceptExp(/*#ref*/ws.exp, av);
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

	status = acceptExp(/*#ref*/ts.exp, av);
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

	status = acceptExp(/*#ref*/as.condition, av);
	if (status != VisitorContinue) {
		return status;
	}

	if (as.message !is null) {
		status = acceptExp(/*#ref*/as.message, av);
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
		status = acceptExp(/*#ref*/ms.stringExp, av);
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
	auto status = av.enter(/*#ref*/exp, postfix);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is postfix) {
		assert(exp !is null);
		return acceptExp(/*#ref*/exp, av);
	}

	if (postfix.child !is null) {
		status = acceptExp(/*#ref*/postfix.child, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	foreach (ref arg; postfix.arguments) {
		if (arg !is null) {
			status = acceptExp(/*#ref*/arg, av);
			if (status == VisitorStop) {
				return VisitorStop;
			}
		}
	}
 
	if (postfix.identifier !is null) {
		status = accept(postfix.identifier, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(/*#ref*/exp, postfix);
}

Visitor.Status acceptUnary(ref ir.Exp exp, ir.Unary unary, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, unary);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is unary) {
		return acceptExp(/*#ref*/exp, av);
	}

	if (unary.type !is null) {
		status = accept(unary.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (unary.value !is null) {
		status = acceptExp(/*#ref*/unary.value, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	foreach (ref arg; unary.argumentList) {
		status = acceptExp(/*#ref*/arg, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (unary.dupBeginning !is null) {
		status = acceptExp(/*#ref*/unary.dupBeginning, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (unary.dupEnd !is null) {
		status = acceptExp(/*#ref*/unary.dupEnd, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(/*#ref*/exp, unary);
}

Visitor.Status acceptBinOp(ref ir.Exp exp, ir.BinOp binop, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, binop);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is binop) {
		return acceptExp(/*#ref*/exp, av);
	}

	status = acceptExp(/*#ref*/binop.left, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(/*#ref*/binop.right, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(/*#ref*/exp, binop);
}

Visitor.Status acceptTernary(ref ir.Exp exp, ir.Ternary ternary, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, ternary);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is ternary) {
		return acceptExp(/*#ref*/exp, av);
	}

	status = acceptExp(/*#ref*/ternary.condition, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(/*#ref*/ternary.ifTrue, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(/*#ref*/ternary.ifFalse, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(/*#ref*/exp, ternary);
}

Visitor.Status acceptArrayLiteral(ref ir.Exp exp, ir.ArrayLiteral array, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is array) {
		return acceptExp(/*#ref*/exp, av);
	}

	if (array.type !is null) {
		status = accept(array.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	foreach (ref childExp; array.exps) {
		status = acceptExp(/*#ref*/childExp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(/*#ref*/exp, array);
}

Visitor.Status acceptAssocArray(ref ir.Exp exp, ir.AssocArray array, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, array);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is array) {
		return acceptExp(/*#ref*/exp, av);
	}

	foreach (ref pair; array.pairs) {
		status = acceptExp(/*#ref*/pair.key, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
		status = acceptExp(/*#ref*/pair.value, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(/*#ref*/exp, array);
}

Visitor.Status acceptAssert(ref ir.Exp exp, ir.Assert _assert, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, _assert);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is _assert) {
		return acceptExp(/*#ref*/exp, av);
	}

	status = acceptExp(/*#ref*/_assert.condition, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	if (_assert.message !is null) {
		status = acceptExp(/*#ref*/_assert.message, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(/*#ref*/exp, _assert);
}

Visitor.Status acceptStringImport(ref ir.Exp exp, ir.StringImport strimport, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, strimport);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is strimport) {
		return acceptExp(/*#ref*/exp, av);
	}

	status = acceptExp(/*#ref*/strimport.filename, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(/*#ref*/exp, strimport);
}

Visitor.Status acceptTypeid(ref ir.Exp exp, ir.Typeid ti, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, ti);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is ti) {
		return acceptExp(/*#ref*/exp, av);
	}

	if (ti.exp !is null) {
		status = acceptExp(/*#ref*/ti.exp, av);
	} else {
		status = accept(ti.type, av);
	}

	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(/*#ref*/exp, ti);
}

Visitor.Status acceptIsExp(ref ir.Exp exp, ir.IsExp isExp, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, isExp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is isExp) {
		return acceptExp(/*#ref*/exp, av);
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

	return av.leave(/*#ref*/exp, isExp);
}

Visitor.Status acceptFunctionLiteral(ref ir.Exp exp, ir.FunctionLiteral functionLiteral, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, functionLiteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is functionLiteral) {
		return acceptExp(/*#ref*/exp, av);
	}

	if (functionLiteral.block !is null) {
		accept(functionLiteral.block, av);
	}

	return av.leave(/*#ref*/exp, functionLiteral);
}

Visitor.Status acceptStructLiteral(ref ir.Exp exp, ir.StructLiteral sliteral, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, sliteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is sliteral) {
		return acceptExp(/*#ref*/exp, av);
	}

	foreach (ref sexp; sliteral.exps) {
		status = acceptExp(/*#ref*/sexp, av);
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

	return av.leave(/*#ref*/exp, sliteral);
}

Visitor.Status acceptUnionLiteral(ref ir.Exp exp, ir.UnionLiteral uliteral, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, uliteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is uliteral) {
		return acceptExp(/*#ref*/exp, av);
	}

	foreach (ref sexp; uliteral.exps) {
		status = acceptExp(/*#ref*/sexp, av);
		if (status == VisitorContinueParent) {
			continue;
		} else if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (uliteral.type !is null) {
		status = accept(uliteral.type, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(/*#ref*/exp, uliteral);
}

Visitor.Status acceptClassLiteral(ref ir.Exp exp, ir.ClassLiteral cliteral, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, cliteral);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is cliteral) {
		return acceptExp(/*#ref*/exp, av);
	}

	foreach (ref sexp; cliteral.exps) {
		status = acceptExp(/*#ref*/sexp, av);
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

	return av.leave(/*#ref*/exp, cliteral);
}

Visitor.Status acceptTypeExp(ref ir.Exp exp, ir.TypeExp texp, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, texp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(texp.type, av);
	if (status != VisitorContinue) {
		return status;
	}

	return av.leave(/*#ref*/exp, texp);
}

Visitor.Status acceptStoreExp(ref ir.Exp exp, ir.StoreExp sexp, Visitor av)
{
	return av.visit(/*#ref*/exp, sexp);
}

Visitor.Status acceptStatementExp(ref ir.Exp exp, ir.StatementExp state, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, state);
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
		status = acceptExp(/*#ref*/state.exp, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(/*#ref*/exp, state);
}

Visitor.Status acceptTokenExp(ref ir.Exp exp, ir.TokenExp fexp, Visitor av)
{
	return av.visit(/*#ref*/exp, fexp);
}

Visitor.Status acceptVaArgExp(ref ir.Exp exp, ir.VaArgExp vaexp, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, vaexp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = accept(vaexp.type, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	status = acceptExp(/*#ref*/vaexp.arg, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(/*#ref*/exp, vaexp);
}

Visitor.Status acceptPropertyExp(ref ir.Exp exp, ir.PropertyExp prop, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, prop);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (prop.child !is null) {
		status = acceptExp(/*#ref*/prop.child, av);
		if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(/*#ref*/exp, prop);
}

Visitor.Status acceptBuiltinExp(ref ir.Exp exp, ir.BuiltinExp inbuilt, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, inbuilt);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (ref child; inbuilt.children) {
		status = acceptExp(/*#ref*/child, av);
		if (status == VisitorContinueParent) {
			continue;
		} else if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	if (exp !is inbuilt) {
		return acceptExp(/*#ref*/exp, av);
	}

	if (inbuilt.type !is null) {
		accept(inbuilt.type, av);
	}

	return av.leave(/*#ref*/exp, inbuilt);
}

Visitor.Status acceptAccessExp(ref ir.Exp exp, ir.AccessExp ae, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, ae);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = acceptExp(/*#ref*/ae.child, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(/*#ref*/exp, ae);
}

Visitor.Status acceptRunExp(ref ir.Exp exp, ir.RunExp runexp, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, runexp);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	status = acceptExp(/*#ref*/runexp.child, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(/*#ref*/exp, runexp);
}

Visitor.Status acceptComposableString(ref ir.Exp exp, ir.ComposableString cs, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, cs);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	foreach (ref component; cs.components) {
		status = acceptExp(/*#ref*/component, av);
		if (status == VisitorContinueParent) {
			continue;
		} else if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(/*#ref*/exp, cs);
}

Visitor.Status acceptExpReference(ref ir.Exp exp, ir.ExpReference expref, Visitor av)
{
	return av.visit(/*#ref*/exp, expref);
}

Visitor.Status acceptConstant(ref ir.Exp exp, ir.Constant constant, Visitor av)
{
	auto status = av.enter(/*#ref*/exp, constant);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	// If exp has been replaced
	if (exp !is constant) {
		return acceptExp(/*#ref*/exp, av);
	}

	status = accept(constant.type, av);
	if (status == VisitorStop) {
		return VisitorStop;
	}

	return av.leave(/*#ref*/exp, constant);
}

Visitor.Status acceptIdentifierExp(ref ir.Exp exp, ir.IdentifierExp identifier, Visitor av)
{
	return av.visit(/*#ref*/exp, identifier);
}

/*
 * Templates
 */

Visitor.Status acceptTemplateInstance(ir.TemplateInstance ti, Visitor av)
{
	auto status = av.enter(ti);
	if (status != VisitorContinue) {
		return parentContinue(status);
	}

	if (ti._struct !is null) {
		accept(ti._struct, av);
	} else if (ti._function !is null) {
		accept(ti._function, av);
	} else if (ti._class !is null) {
		accept(ti._class, av);
	} else if (ti._union !is null) {
		accept(ti._union, av);
	} else if (ti._interface !is null) {
		accept(ti._interface, av);
	}

	foreach (i, arg; ti.arguments) {
		if (status == VisitorContinueParent) {
			continue;
		} else if (status == VisitorStop) {
			return VisitorStop;
		}
	}

	return av.leave(ti);
}

Visitor.Status acceptTemplateDefinition(ir.TemplateDefinition td, Visitor av)
{
	return av.visit(td);
}
