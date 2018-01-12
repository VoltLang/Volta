/*#D*/
// Copyright © 2012-2017, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012-2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.ir.base;

import watt.conv : toString;
import watt.text.sink : StringSink;

public import volta.ir.location : Location;
public import volta.ir.token : Token, TokenType;

import volta.ir.type;
import volta.ir.toplevel;
import volta.ir.statement;
import volta.ir.templates;
import volta.ir.expression;
import volta.ir.declaration;

import volta.util.dup;


/*!
 * @defgroup irNode IR Nodes
 */

/*!
 * Each concrete class derived from @p ir.Node has a value in this
 * enumeration. The value for the type is stored in @p ir.Node.nodeType
 * by the constructor. While using type tags is not very OOP, it is
 * extremely convenient. For example, during debugging you can simply
 * inspect @p ir.Node.nodeType to find out the actual type of the object.
 *
 * In addition, it is possible to use a switch-statement based on
 * @p ir.Node.nodeType to select different behaviour for different object
 * types. For functions that have only slight differences for several
 * object types, this allows writing very straightforward, readable
 * code.
 *
 * Comment totally stolen from Mesa code.
 *
 * @ingroup irNode
 */
enum NodeType
{
	/* base.d */
	Invalid,
	NonVisiting,
	QualifiedName,
	Identifier,

	/* toplevel.d */
	Module,
	TopLevelBlock,
	Import,
	Unittest,
	Struct,
	Class,
	Interface,
	Union,
	Enum,
	Attribute,
	Condition,
	ConditionTopLevel,
	MixinFunction,
	MixinTemplate,

	/* type.d */
	PrimitiveType,
	TypeReference,
	PointerType,
	ArrayType,
	AmbiguousArrayType,
	StaticArrayType,
	AAType,
	AAPair,
	FunctionType,
	DelegateType,
	FunctionSetType,
	StorageType,
	TypeOf,
	NullType,
	AutoType,
	NoType,
	AliasStaticIf,

	/* declaration.d */
	Variable,
	Alias,
	Function,
	FunctionParam,
	FunctionSet,
	EnumDeclaration,

	/* statements.d */
	ReturnStatement,
	BlockStatement,
	AsmStatement,
	IfStatement,
	WhileStatement,
	DoStatement,
	ForStatement,
	ForeachStatement,
	LabelStatement,
	ExpStatement,
	SwitchStatement,
	SwitchCase,
	ContinueStatement,
	BreakStatement,
	GotoStatement,
	WithStatement,
	SynchronizedStatement,
	TryStatement,
	ThrowStatement,
	ScopeStatement,
	PragmaStatement,
	ConditionStatement,
	MixinStatement,
	AssertStatement,

	/* expression.d */
	Constant,
	BinOp,
	Ternary,
	Unary,
	Postfix,
	ArrayLiteral,
	AssocArray,
	IdentifierExp,
	Assert,
	StringImport,
	Typeid,
	IsExp,
	FunctionLiteral,
	ExpReference,
	StructLiteral,
	UnionLiteral,
	ClassLiteral,
	TypeExp,
	StoreExp,
	StatementExp,
	TokenExp,
	VaArgExp,
	PropertyExp,
	BuiltinExp,
	AccessExp,
	RunExp,
	ComposableString,

	/* templates.d */
	TemplateInstance,
	TemplateDefinition,
}

/*!
 * Common access levels used on declared functions, methods, classes,
 * interfaces, structs, enums and variables.
 *
 * @ingroup irNode
 */
enum Access
{
	Invalid,
	Public = TokenType.Public,
	Private = TokenType.Private,
	Protected = TokenType.Protected,
}

/*!
 * Return the given @p Access as a string.
 *
 * @ingroup irNode.
 */
string accessToString(Access access)
{
	final switch (access) with (Access) {
	case Invalid:   return "(invalid)";
	case Public:    return "public";
	case Protected: return "protected";
	case Private:   return "private";
	}
}

/*!
 * Controls the calling convention and how symbols are mangled.
 *
 * Linkages are mangled in functions like so:
 *   - @p Volt is mangled as "Q".
 *   - @p C is mangled as "U".
 *   - @p CPlusPlus is mangled as "R".
 *   - @p D is mangled as "F".
 *   - @p Windows is mangled as "W".
 *   - @p Pascal is mangled as "V".
 *   - @p System is as @p C on non Windows systems, and as @p Windows on Windows systems.
 *
 * @ingroup irNode
 */
enum Linkage
{
	Volt,
	C,
	CPlusPlus,
	D,
	Windows,
	Pascal,
	System,
}

/*!
 * Return the given @p Linkage as a string.
 *
 * @ingroup irNode.
 */
string linkageToString(Linkage linkage)
{
	final switch (linkage) with (Linkage) {
	case Volt: return "volt";
	case C: return "c";
	case CPlusPlus: return "c++";
	case D: return "d";
	case Windows: return "windows";
	case Pascal: return "pascal";
	case System: return "system";
	}
}

/*!
 * Used by ScopeStatement and other nodes.
 *
 * @ingroup irNode irStatement
 */
enum ScopeKind
{
	Exit,
	Failure,
	Success,
}

/*!
 * Type used for node unique ids.
 */
alias NodeID = size_t;

/*!
 * Base class for all IR nodes.
 * 
 * A Node has a Location and a type. The Location points
 * to where in the source code this Node was defined, and
 * the NodeType allows you to determine the more specific
 * IR type of it.
 *
 * @ingroup irNode
 */
abstract class Node
{
public:
	//! Where in the source this Node was defined, for diagnostic purposes.
	Location loc;

	//! Retrieve the NodeType for this Node.
	final @property NodeType nodeType() { return mNodeType; }

	//! Retrieve the unique id of this node.
	final @property size_t uniqueId() { return mUniqueId; }

	//! Documentation comment attached to this node, if any.
	string docComment;


protected:
	this(NodeType nt)
	{
		this.mNodeType = nt;
		this.mUniqueId = mUniqueIdCounter++;
	}

	this(NodeType nt, Node old)
	{
		this(nt);  // Setup uniqueId.
		this.loc = old.loc;
	}


public:
	// Base
	final Identifier toIdentifierFast() { return cast(Identifier)cast(void*)this; }
	final Identifier toIdentifierChecked() { if (nodeType == NodeType.Identifier) return toIdentifierFast(); else return null; }
	final QualifiedName toQualifiedNameFast() { return cast(QualifiedName)cast(void*)this; }
	final QualifiedName toQualifiedNameChecked() { if (nodeType == NodeType.QualifiedName) return toQualifiedNameFast(); else return null; }

	// Toplevel
	final Module toModuleFast() { return cast(Module)cast(void*)this; }
	final Module toModuleChecked() { if (nodeType == NodeType.Module) return toModuleFast(); else return null; }
	final TopLevelBlock toTopLevelBlockFast() { return cast(TopLevelBlock)cast(void*)this; }
	final TopLevelBlock toTopLevelBlockChecked() { if (nodeType == NodeType.TopLevelBlock) return toTopLevelBlockFast(); else return null; }
	final Import toImportFast() { return cast(Import)cast(void*)this; }
	final Import toImportChecked() { if (nodeType == NodeType.Import) return toImportFast(); else return null; }
	final Unittest toUnittestFast() { return cast(Unittest)cast(void*)this; }
	final Unittest toUnittestChecked() { if (nodeType == NodeType.Unittest) return toUnittestFast(); else return null; }
	final Struct toStructFast() { return cast(Struct)cast(void*)this; }
	final Struct toStructChecked() { if (nodeType == NodeType.Struct) return toStructFast(); else return null; }
	final Class toClassFast() { return cast(Class)cast(void*)this; }
	final Class toClassChecked() { if (nodeType == NodeType.Class) return toClassFast(); else return null; }
	final _Interface toInterfaceFast() { return cast(_Interface)cast(void*)this; }
	final _Interface toInterfaceChecked() { if (nodeType == NodeType.Interface) return toInterfaceFast(); else return null; }
	final Union toUnionFast() { return cast(Union)cast(void*)this; }
	final Union toUnionChecked() { if (nodeType == NodeType.Union) return toUnionFast(); else return null; }
	final Enum toEnumFast() { return cast(Enum)cast(void*)this; }
	final Enum toEnumChecked() { if (nodeType == NodeType.Enum) return toEnumFast(); else return null; }
	final Attribute toAttributeFast() { return cast(Attribute)cast(void*)this; }
	final Attribute toAttributeChecked() { if (nodeType == NodeType.Attribute) return toAttributeFast(); else return null; }
	final Condition toConditionFast() { return cast(Condition)cast(void*)this; }
	final Condition toConditionChecked() { if (nodeType == NodeType.Condition) return toConditionFast(); else return null; }
	final ConditionTopLevel toConditionTopLevelFast() { return cast(ConditionTopLevel)cast(void*)this; }
	final ConditionTopLevel toConditionTopLevelChecked() { if (nodeType == NodeType.ConditionTopLevel) return toConditionTopLevelFast(); else return null; }
	final MixinFunction toMixinFunctionFast() { return cast(MixinFunction)cast(void*)this; }
	final MixinFunction toMixinFunctionChecked() { if (nodeType == NodeType.MixinFunction) return toMixinFunctionFast(); else return null; }
	final MixinTemplate toMixinTemplateFast() { return cast(MixinTemplate)cast(void*)this; }
	final MixinTemplate toMixinTemplateChecked() { if (nodeType == NodeType.MixinTemplate) return toMixinTemplateFast(); else return null; }

	// Type
	final Type toTypeFast() { return cast(Type)cast(void*)this; }
	final Type toTypeChecked() { return cast(Type)this; }
	final PrimitiveType toPrimitiveTypeFast() { return cast(PrimitiveType)cast(void*)this; }
	final PrimitiveType toPrimitiveTypeChecked() { if (nodeType == NodeType.PrimitiveType) return toPrimitiveTypeFast(); else return null; }
	final TypeReference toTypeReferenceFast() { return cast(TypeReference)cast(void*)this; }
	final TypeReference toTypeReferenceChecked() { if (nodeType == NodeType.TypeReference) return toTypeReferenceFast(); else return null; }
	final PointerType toPointerTypeFast() { return cast(PointerType)cast(void*)this; }
	final PointerType toPointerTypeChecked() { if (nodeType == NodeType.PointerType) return toPointerTypeFast(); else return null; }
	final ArrayType toArrayTypeFast() { return cast(ArrayType)cast(void*)this; }
	final ArrayType toArrayTypeChecked() { if (nodeType == NodeType.ArrayType) return toArrayTypeFast(); else return null; }
	final AmbiguousArrayType toAmbiguousArrayTypeFast() { return cast(AmbiguousArrayType)cast(void*)this; }
	final AmbiguousArrayType toAmbiguousArrayTypeChecked() { if (nodeType == NodeType.AmbiguousArrayType) return toAmbiguousArrayTypeFast(); else return null; }
	final StaticArrayType toStaticArrayTypeFast() { return cast(StaticArrayType)cast(void*)this; }
	final StaticArrayType toStaticArrayTypeChecked() { if (nodeType == NodeType.StaticArrayType) return toStaticArrayTypeFast(); else return null; }
	final AAType toAATypeFast() { return cast(AAType)cast(void*)this; }
	final AAType toAATypeChecked() { if (nodeType == NodeType.AAType) return toAATypeFast(); else return null; }
	final AAPair toAAPairFast() { return cast(AAPair)cast(void*)this; }
	final AAPair toAAPairChecked() { if (nodeType == NodeType.AAPair) return toAAPairFast(); else return null; }
	final FunctionType toFunctionTypeFast() { return cast(FunctionType)cast(void*)this; }
	final FunctionType toFunctionTypeChecked() { if (nodeType == NodeType.FunctionType) return toFunctionTypeFast(); else return null; }
	final DelegateType toDelegateTypeFast() { return cast(DelegateType)cast(void*)this; }
	final DelegateType toDelegateTypeChecked() { if (nodeType == NodeType.DelegateType) return toDelegateTypeFast(); else return null; }
	final FunctionSetType toFunctionSetTypeFast() { return cast(FunctionSetType)cast(void*)this; }
	final FunctionSetType toFunctionSetTypeChecked() { if (nodeType == NodeType.FunctionSetType) return toFunctionSetTypeFast(); else return null; }
	final StorageType toStorageTypeFast() { return cast(StorageType)cast(void*)this; }
	final StorageType toStorageTypeChecked() { if (nodeType == NodeType.StorageType) return toStorageTypeFast(); else return null; }
	final TypeOf toTypeOfFast() { return cast(TypeOf)cast(void*)this; }
	final TypeOf toTypeOfChecked() { if (nodeType == NodeType.TypeOf) return toTypeOfFast(); else return null; }
	final NullType toNullTypeFast() { return cast(NullType)cast(void*)this; }
	final NullType toNullTypeChecked() { if (nodeType == NodeType.NullType) return toNullTypeFast(); else return null; }
	final AutoType toAutoTypeFast() { return cast(AutoType)cast(void*)this; }
	final AutoType toAutoTypeChecked() { if (nodeType == NodeType.AutoType) return toAutoTypeFast(); else return null; }
	final NoType toNoTypeFast() { return cast(NoType)cast(void*)this; }
	final NoType toNoTypeChecked() { if (nodeType == NodeType.NoType) return toNoTypeFast(); else return null; }
	final AliasStaticIf toAliasStaticIfFast() { return cast(AliasStaticIf)cast(void*)this; }
	final AliasStaticIf toAliasStaticIfChecked() { if (nodeType == NodeType.AliasStaticIf) return toAliasStaticIfFast(); else return null; }
	final CallableType toCallableTypeFast() { return cast(CallableType)cast(void*)this; }
	final CallableType toCallableTypeChecked() { if (nodeType == NodeType.DelegateType || nodeType == NodeType.FunctionType) return toCallableTypeFast(); else return null; }

	// Declaration
	final Variable toVariableFast() { return cast(Variable)cast(void*)this; }
	final Variable toVariableChecked() { if (nodeType == NodeType.Variable) return toVariableFast(); else return null; }
	final Alias toAliasFast() { return cast(Alias)cast(void*)this; }
	final Alias toAliasChecked() { if (nodeType == NodeType.Alias) return toAliasFast(); else return null; }
	final Function toFunctionFast() { return cast(Function)cast(void*)this; }
	final Function toFunctionChecked() { if (nodeType == NodeType.Function) return toFunctionFast(); else return null; }
	final FunctionParam toFunctionParamFast() { return cast(FunctionParam)cast(void*)this; }
	final FunctionParam toFunctionParamChecked() { if (nodeType == NodeType.FunctionParam) return toFunctionParamFast(); else return null; }
	final FunctionSet toFunctionSetFast() { return cast(FunctionSet)cast(void*)this; }
	final FunctionSet toFunctionSetChecked() { if (nodeType == NodeType.FunctionSet) return toFunctionSetFast(); else return null; }
	final EnumDeclaration toEnumDeclarationFast() { return cast(EnumDeclaration)cast(void*)this; }
	final EnumDeclaration toEnumDeclarationChecked() { if (nodeType == NodeType.EnumDeclaration) return toEnumDeclarationFast(); else return null; }

	// Statements
	final ReturnStatement toReturnStatementFast() { return cast(ReturnStatement)cast(void*)this; }
	final ReturnStatement toReturnStatementChecked() { if (nodeType == NodeType.ReturnStatement) return toReturnStatementFast(); else return null; }
	final BlockStatement toBlockStatementFast() { return cast(BlockStatement)cast(void*)this; }
	final BlockStatement toBlockStatementChecked() { if (nodeType == NodeType.BlockStatement) return toBlockStatementFast(); else return null; }
	final AsmStatement toAsmStatementFast() { return cast(AsmStatement)cast(void*)this; }
	final AsmStatement toAsmStatementChecked() { if (nodeType == NodeType.AsmStatement) return toAsmStatementFast(); else return null; }
	final IfStatement toIfStatementFast() { return cast(IfStatement)cast(void*)this; }
	final IfStatement toIfStatementChecked() { if (nodeType == NodeType.IfStatement) return toIfStatementFast(); else return null; }
	final WhileStatement toWhileStatementFast() { return cast(WhileStatement)cast(void*)this; }
	final WhileStatement toWhileStatementChecked() { if (nodeType == NodeType.WhileStatement) return toWhileStatementFast(); else return null; }
	final DoStatement toDoStatementFast() { return cast(DoStatement)cast(void*)this; }
	final DoStatement toDoStatementChecked() { if (nodeType == NodeType.DoStatement) return toDoStatementFast(); else return null; }
	final ForStatement toForStatementFast() { return cast(ForStatement)cast(void*)this; }
	final ForStatement toForStatementChecked() { if (nodeType == NodeType.ForStatement) return toForStatementFast(); else return null; }
	final ForeachStatement toForeachStatementFast() { return cast(ForeachStatement)cast(void*)this; }
	final ForeachStatement toForeachStatementChecked() { if (nodeType == NodeType.ForeachStatement) return toForeachStatementFast(); else return null; }
	final LabelStatement toLabelStatementFast() { return cast(LabelStatement)cast(void*)this; }
	final LabelStatement toLabelStatementChecked() { if (nodeType == NodeType.LabelStatement) return toLabelStatementFast(); else return null; }
	final ExpStatement toExpStatementFast() { return cast(ExpStatement)cast(void*)this; }
	final ExpStatement toExpStatementChecked() { if (nodeType == NodeType.ExpStatement) return toExpStatementFast(); else return null; }
	final SwitchStatement toSwitchStatementFast() { return cast(SwitchStatement)cast(void*)this; }
	final SwitchStatement toSwitchStatementChecked() { if (nodeType == NodeType.SwitchStatement) return toSwitchStatementFast(); else return null; }
	final SwitchCase toSwitchCaseFast() { return cast(SwitchCase)cast(void*)this; }
	final SwitchCase toSwitchCaseChecked() { if (nodeType == NodeType.SwitchCase) return toSwitchCaseFast(); else return null; }
	final ContinueStatement toContinueStatementFast() { return cast(ContinueStatement)cast(void*)this; }
	final ContinueStatement toContinueStatementChecked() { if (nodeType == NodeType.ContinueStatement) return toContinueStatementFast(); else return null; }
	final BreakStatement toBreakStatementFast() { return cast(BreakStatement)cast(void*)this; }
	final BreakStatement toBreakStatementChecked() { if (nodeType == NodeType.BreakStatement) return toBreakStatementFast(); else return null; }
	final GotoStatement toGotoStatementFast() { return cast(GotoStatement)cast(void*)this; }
	final GotoStatement toGotoStatementChecked() { if (nodeType == NodeType.GotoStatement) return toGotoStatementFast(); else return null; }
	final WithStatement toWithStatementFast() { return cast(WithStatement)cast(void*)this; }
	final WithStatement toWithStatementChecked() { if (nodeType == NodeType.WithStatement) return toWithStatementFast(); else return null; }
	final SynchronizedStatement toSynchronizedStatementFast() { return cast(SynchronizedStatement)cast(void*)this; }
	final SynchronizedStatement toSynchronizedStatementChecked() { if (nodeType == NodeType.SynchronizedStatement) return toSynchronizedStatementFast(); else return null; }
	final TryStatement toTryStatementFast() { return cast(TryStatement)cast(void*)this; }
	final TryStatement toTryStatementChecked() { if (nodeType == NodeType.TryStatement) return toTryStatementFast(); else return null; }
	final ThrowStatement toThrowStatementFast() { return cast(ThrowStatement)cast(void*)this; }
	final ThrowStatement toThrowStatementChecked() { if (nodeType == NodeType.ThrowStatement) return toThrowStatementFast(); else return null; }
	final ScopeStatement toScopeStatementFast() { return cast(ScopeStatement)cast(void*)this; }
	final ScopeStatement toScopeStatementChecked() { if (nodeType == NodeType.ScopeStatement) return toScopeStatementFast(); else return null; }
	final PragmaStatement toPragmaStatementFast() { return cast(PragmaStatement)cast(void*)this; }
	final PragmaStatement toPragmaStatementChecked() { if (nodeType == NodeType.PragmaStatement) return toPragmaStatementFast(); else return null; }
	final ConditionStatement toConditionStatementFast() { return cast(ConditionStatement)cast(void*)this; }
	final ConditionStatement toConditionStatementChecked() { if (nodeType == NodeType.ConditionStatement) return toConditionStatementFast(); else return null; }
	final MixinStatement toMixinStatementFast() { return cast(MixinStatement)cast(void*)this; }
	final MixinStatement toMixinStatementChecked() { if (nodeType == NodeType.MixinStatement) return toMixinStatementFast(); else return null; }
	final AssertStatement toAssertStatementFast() { return cast(AssertStatement)cast(void*)this; }
	final AssertStatement toAssertStatementChecked() { if (nodeType == NodeType.AssertStatement) return toAssertStatementFast(); else return null; }

	// Expression
	final Constant toConstantFast() { return cast(Constant)cast(void*)this; }
	final Constant toConstantChecked() { if (nodeType == NodeType.Constant) return toConstantFast(); else return null; }
	final BinOp toBinOpFast() { return cast(BinOp)cast(void*)this; }
	final BinOp toBinOpChecked() { if (nodeType == NodeType.BinOp) return toBinOpFast(); else return null; }
	final Ternary toTernaryFast() { return cast(Ternary)cast(void*)this; }
	final Ternary toTernaryChecked() { if (nodeType == NodeType.Ternary) return toTernaryFast(); else return null; }
	final Unary toUnaryFast() { return cast(Unary)cast(void*)this; }
	final Unary toUnaryChecked() { if (nodeType == NodeType.Unary) return toUnaryFast(); else return null; }
	final Postfix toPostfixFast() { return cast(Postfix)cast(void*)this; }
	final Postfix toPostfixChecked() { if (nodeType == NodeType.Postfix) return toPostfixFast(); else return null; }
	final ArrayLiteral toArrayLiteralFast() { return cast(ArrayLiteral)cast(void*)this; }
	final ArrayLiteral toArrayLiteralChecked() { if (nodeType == NodeType.ArrayLiteral) return toArrayLiteralFast(); else return null; }
	final AssocArray toAssocArrayFast() { return cast(AssocArray)cast(void*)this; }
	final AssocArray toAssocArrayChecked() { if (nodeType == NodeType.AssocArray) return toAssocArrayFast(); else return null; }
	final IdentifierExp toIdentifierExpFast() { return cast(IdentifierExp)cast(void*)this; }
	final IdentifierExp toIdentifierExpChecked() { if (nodeType == NodeType.IdentifierExp) return toIdentifierExpFast(); else return null; }
	final Assert toAssertFast() { return cast(Assert)cast(void*)this; }
	final Assert toAssertChecked() { if (nodeType == NodeType.Assert) return toAssertFast(); else return null; }
	final StringImport toStringImportFast() { return cast(StringImport)cast(void*)this; }
	final StringImport toStringImportChecked() { if (nodeType == NodeType.StringImport) return toStringImportFast(); else return null; }
	final Typeid toTypeidFast() { return cast(Typeid)cast(void*)this; }
	final Typeid toTypeidChecked() { if (nodeType == NodeType.Typeid) return toTypeidFast(); else return null; }
	final IsExp toIsExpFast() { return cast(IsExp)cast(void*)this; }
	final IsExp toIsExpChecked() { if (nodeType == NodeType.IsExp) return toIsExpFast(); else return null; }
	final FunctionLiteral toFunctionLiteralFast() { return cast(FunctionLiteral)cast(void*)this; }
	final FunctionLiteral toFunctionLiteralChecked() { if (nodeType == NodeType.FunctionLiteral) return toFunctionLiteralFast(); else return null; }
	final ExpReference toExpReferenceFast() { return cast(ExpReference)cast(void*)this; }
	final ExpReference toExpReferenceChecked() { if (nodeType == NodeType.ExpReference) return toExpReferenceFast(); else return null; }
	final StructLiteral toStructLiteralFast() { return cast(StructLiteral)cast(void*)this; }
	final StructLiteral toStructLiteralChecked() { if (nodeType == NodeType.StructLiteral) return toStructLiteralFast(); else return null; }
	final UnionLiteral toUnionLiteralFast() { return cast(UnionLiteral)cast(void*)this; }
	final UnionLiteral toUnionLiteralChecked() { if (nodeType == NodeType.UnionLiteral) return toUnionLiteralFast(); else return null; }
	final ClassLiteral toClassLiteralFast() { return cast(ClassLiteral)cast(void*)this; }
	final ClassLiteral toClassLiteralChecked() { if (nodeType == NodeType.ClassLiteral) return toClassLiteralFast(); else return null; }
	final TypeExp toTypeExpFast() { return cast(TypeExp)cast(void*)this; }
	final TypeExp toTypeExpChecked() { if (nodeType == NodeType.TypeExp) return toTypeExpFast(); else return null; }
	final StoreExp toStoreExpFast() { return cast(StoreExp)cast(void*)this; }
	final StoreExp toStoreExpChecked() { if (nodeType == NodeType.StoreExp) return toStoreExpFast(); else return null; }
	final StatementExp toStatementExpFast() { return cast(StatementExp)cast(void*)this; }
	final StatementExp toStatementExpChecked() { if (nodeType == NodeType.StatementExp) return toStatementExpFast(); else return null; }
	final TokenExp toTokenExpFast() { return cast(TokenExp)cast(void*)this; }
	final TokenExp toTokenExpChecked() { if (nodeType == NodeType.TokenExp) return toTokenExpFast(); else return null; }
	final VaArgExp toVaArgExpFast() { return cast(VaArgExp)cast(void*)this; }
	final VaArgExp toVaArgExpChecked() { if (nodeType == NodeType.VaArgExp) return toVaArgExpFast(); else return null; }
	final PropertyExp toPropertyExpFast() { return cast(PropertyExp)cast(void*)this; }
	final PropertyExp toPropertyExpChecked() { if (nodeType == NodeType.PropertyExp) return toPropertyExpFast(); else return null; }
	final BuiltinExp toBuiltinExpFast() { return cast(BuiltinExp)cast(void*)this; }
	final BuiltinExp toBuiltinExpChecked() { if (nodeType == NodeType.BuiltinExp) return toBuiltinExpFast(); else return null; }
	final AccessExp toAccessExpFast() { return cast(AccessExp)cast(void*)this; }
	final AccessExp toAccessExpChecked() { if (nodeType == NodeType.AccessExp) return toAccessExpFast(); else return null; }
	final RunExp toRunExpFast() { return cast(RunExp)cast(void*)this; }
	final RunExp toRunExpChecked() { if (nodeType == NodeType.RunExp) return toRunExpFast(); else return null; }
	final ComposableString toComposableStringFast() { return cast(ComposableString)cast(void*)this; }
	final ComposableString toComposableStringChecked() { if (nodeType == NodeType.ComposableString) return toComposableStringFast(); else return null; }

	// Templates
	final TemplateInstance toTemplateInstanceFast() { return cast(TemplateInstance)cast(void*)this; }
	final TemplateInstance toTemplateInstanceChecked() { if (nodeType == NodeType.TemplateInstance) return toTemplateInstanceFast(); else return null; }
	final TemplateDefinition toTemplateDefinitionFast() { return cast(TemplateDefinition)cast(void*)this; }
	final TemplateDefinition toTemplateDefinitionChecked() { if (nodeType == NodeType.TemplateDefinition) return toTemplateDefinitionFast(); else return null; }


private:
	NodeType mNodeType;
	NodeID mUniqueId;
	static NodeID mUniqueIdCounter; // We are single threaded.
}

/*!
 * A series of identifiers and dots referring to a declared item.
 *
 * @ingroup irNode
 */
class QualifiedName : Node
{
public:
	//! The last identifier is the module, any preceding identifiers are packages.
	Identifier[] identifiers;
	//! If true, this name starts with a dot.
	bool leadingDot;


public:
	override string toString()
	{
		StringSink str;
		foreach (i, identifier; identifiers) {
			str.sink(identifier.value);
			if (i < identifiers.length - 1) {
				str.sink(".");
			}
		}
		return str.toString();
	}

	@property string[] strings()
	{
		string[] ret = new string[](identifiers.length);

		foreach (i, identifier; identifiers) {
			ret[i] = identifier.value;
		}

		return ret;
	}


public:
	this() { super(NodeType.QualifiedName); }

	this(QualifiedName old)
	{
		super(NodeType.QualifiedName, old);
		this.identifiers = old.identifiers.dup();
		this.leadingDot = old.leadingDot;
	}
}

/*!
 * A single string that could be a part of an ir.QualifiedName or
 * stand-alone node inside of the ir, referencing a declared item.
 *
 * @ingroup irNode
 */
class Identifier : Node
{
public:
	//! The string for this Identifier.
	string value;


public:
	this() { super(NodeType.Identifier); }

	this(string s)
	{
		this();
		value = s;
	}

	this(Identifier old)
	{
		super(NodeType.Identifier, old);
		this.value = old.value;
	}
}

/*!
 * Returns a string representing the node's nodeType.
 *
 * @ingroup irNode
 */
string nodeToString(Node node)
{
	return nodeToString(node.nodeType);
}

/*!
 * Returns a string representing the nodeType.
 * 
 * This is just a string representing the Node's name, it doesn't
 * supply strings appropriate for error messages, for example.
 *
 * @ingroup irNode
 */
string nodeToString(NodeType nodeType)
{
	final switch(nodeType) with(NodeType) {
	case Invalid: return "Invalid";
	case NonVisiting: return "NonVisiting";
	case QualifiedName: return "QualifiedName";
	case Identifier: return "Identifier";
	case Module: return "Module";
	case TopLevelBlock: return "TopLevelBlock";
	case Import: return "Import";
	case Unittest: return "Unittest";
	case Struct: return "Struct";
	case Class: return "Class";
	case Interface: return "Interface";
	case Union: return "Union";
	case Enum: return "Enum";
	case EnumDeclaration: return "EnumDeclaration";
	case Attribute: return "Attribute";
	case MixinFunction: return "MixinFunction";
	case MixinTemplate: return "MixinTemplate";
	case Condition: return "Condition";
	case ConditionTopLevel: return "ConditionTopLevel";
	case FunctionSetType: return "FunctionSetType";
	case FunctionSet: return "FunctionSet";
	case PrimitiveType: return "PrimitiveType";
	case TypeReference: return "TypeReference";
	case PointerType: return "PointerType";
	case NullType: return "NullType";
	case ArrayType: return "ArrayType";
	case StaticArrayType: return "StaticArrayType";
	case AAType: return "AAType";
	case AmbiguousArrayType: return "AmbiguousArrayType";
	case AAPair: return "AAPair";
	case FunctionType: return "FunctionType";
	case DelegateType: return "DelegateType";
	case StorageType: return "StorageType";
	case TypeOf: return "TypeOf";
	case Variable: return "Variable";
	case Alias: return "Alias";
	case Function: return "Function";
	case FunctionParam: return "FunctionParam";
	case ReturnStatement: return "ReturnStatement";
	case BlockStatement: return "BlockStatement";
	case AsmStatement: return "AsmStatement";
	case IfStatement: return "IfStatement";
	case WhileStatement: return "WhileStatement";
	case DoStatement: return "DoStatement";
	case ForStatement: return "ForStatement";
	case ForeachStatement: return "ForeachStatement";
	case LabelStatement: return "LabelStatement";
	case ExpStatement: return "ExpStatement";
	case SwitchStatement: return "SwitchStatement";
	case SwitchCase: return "SwitchCase";
	case ContinueStatement: return "ContinueStatement";
	case BreakStatement: return "BreakStatement";
	case GotoStatement: return "GotoStatement";
	case WithStatement: return "WithStatement";
	case SynchronizedStatement: return "SynchronizedStatement";
	case TryStatement: return "TryStatement";
	case ThrowStatement: return "ThrowStatement";
	case ScopeStatement: return "ScopeStatement";
	case PragmaStatement: return "PragmaStatement";
	case ConditionStatement: return "ConditionStatement";
	case MixinStatement: return "MixinStatement";
	case AssertStatement: return "AssertStatement";
	case Constant: return "Constant";
	case BinOp: return "BinOp";
	case Ternary: return "Ternary";
	case Unary: return "Unary";
	case Postfix: return "Postfix";
	case ArrayLiteral: return "ArrayLiteral";
	case AssocArray: return "AssocArray";
	case IdentifierExp: return "IdentifierExp";
	case Assert: return "Assert";
	case StringImport: return "StringImport";
	case Typeid: return "Typeid";
	case IsExp: return "IsExp";
	case FunctionLiteral: return "FunctionLiteral";
	case ExpReference: return "ExpReference";
	case StructLiteral: return "StructLiteral";
	case UnionLiteral: return "UnionLiteral";
	case ClassLiteral: return "ClassLiteral";
	case TypeExp: return "TypeExp";
	case StoreExp: return "StoreExp";
	case StatementExp: return "StatementExp";
	case TokenExp: return "TokenExp";
	case VaArgExp: return "VaArgExp";
	case PropertyExp: return "PropertyExp";
	case AutoType: return "AutoType";
	case BuiltinExp: return "BuiltinExp";
	case NoType: return "NoType";
	case AliasStaticIf: return "AliasStaticIf";
	case AccessExp: return "AccessExp";
	case RunExp: return "RunExp";
	case ComposableString: return "ComposableString";
	case TemplateInstance: return "TemplateInstance";
	case TemplateDefinition: return "TemplateDefinition";
	}
}

/*!
 * For debugging helpers.
 */
string getNodeAddressString(Node node)
{
	version (D_Version2) { // Volt appends 0x on toString.
		return "0x" ~ toString(cast(void*)node);
	} else {
		return toString(cast(void*)node);
	}
}

/*!
 * For debugging helpers.
 */
string getNodeUniqueString(Node node)
{
	return toString(node.uniqueId);
}
