// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.base;

import watt.conv : toString;
import watt.text.sink : StringSink;

public import volt.token.location : Location;
public import volt.token.token : Token, TokenType;

import volt.ir.type;
import volt.ir.toplevel;
import volt.ir.statement;
import volt.ir.templates;
import volt.ir.expression;
import volt.ir.declaration;


/**
 * Each concrete class derived from ir.Node has a value in this
 * enumerant. The value for the type is stored in ir.Node.nodeType
 * by the constructor. While using type tags is not very OOP, it is
 * extremely convenient. For example, during debugging you can simply
 * inspect ir.Node.nodeType to find out the actual type of the object.
 *
 * In addition, it is possible to use a switch-statement based on
 * ir.Node.nodeType to select different behavior for different object
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

	/* declaration.d */
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
	FunctionSet,
	StorageType,
	Variable,
	Alias,
	Function,
	FunctionParam,
	TypeOf,
	NullType,
	EnumDeclaration,
	AutoType,
	NoType,

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

	/* templates.d */
	TemplateInstance,
	TemplateDefinition,
}

/**
 * Common access levels used on declared functions, methods, classes,
 * interfaces, structs, enums and variables.
 *
 * @ingroup irNode
 */
enum Access {
	Invalid,
	Public = TokenType.Public,
	Private = TokenType.Private,
	Protected = TokenType.Protected,
}

/**
 * Controls the calling convention and how symbols are mangled.
 *
 * Linkages are mangled in functions like so:
 * @li @p Volt is mangled as "Q".
 * @li @p C is mangled as "U".
 * @li @p CPlusPlus is mangled as "R".
 * @li @p D is mangled as "F".
 * @li @p Windows is mangled as "W".
 * @li @p Pascal is mangled as "V".
 * @li @p System is as @p C on non Windows systems, and as @p Windows on Windows systems.
 *
 * @ingroup irNode
 */
enum Linkage {
	Volt,
	C,
	CPlusPlus,
	D,
	Windows,
	Pascal,
	System,
}

/**
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

/**
 * Type used for node unique ids.
 */
alias NodeID = size_t;

/**
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
	/// Where in the source this Node was defined, for diagnostic purposes.
	Location loc;

	/// Retrieve the NodeType for this Node.
	@property NodeType nodeType() { return mNodeType; }

	/// Retrieve the unique id of this node.
	@property size_t uniqueId() { return mUniqueId; }

	/// Documentation comment attached to this node, if any.
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
	final QualifiedName toQualifiedNameFast() { return cast(QualifiedName)cast(void*)this; }

	// Toplevel
	final Module toModuleFast() { return cast(Module)cast(void*)this; }
	final TopLevelBlock toTopLevelBlockFast() { return cast(TopLevelBlock)cast(void*)this; }
	final Import toImportFast() { return cast(Import)cast(void*)this; }
	final Unittest toUnittestFast() { return cast(Unittest)cast(void*)this; }
	final Struct toStructFast() { return cast(Struct)cast(void*)this; }
	final Class toClassFast() { return cast(Class)cast(void*)this; }
	final _Interface toInterfaceFast() { return cast(_Interface)cast(void*)this; }
	final Union toUnionFast() { return cast(Union)cast(void*)this; }
	final Enum toEnumFast() { return cast(Enum)cast(void*)this; }
	final Attribute toAttributeFast() { return cast(Attribute)cast(void*)this; }
	final Condition toConditionFast() { return cast(Condition)cast(void*)this; }
	final ConditionTopLevel toConditionTopLevelFast() { return cast(ConditionTopLevel)cast(void*)this; }
	final MixinFunction toMixinFunctionFast() { return cast(MixinFunction)cast(void*)this; }
	final MixinTemplate toMixinTemplateFast() { return cast(MixinTemplate)cast(void*)this; }

	// Type
	final PrimitiveType toPrimitiveTypeFast() { return cast(PrimitiveType)cast(void*)this; }
	final TypeReference toTypeReferenceFast() { return cast(TypeReference)cast(void*)this; }
	final PointerType toPointerTypeFast() { return cast(PointerType)cast(void*)this; }
	final ArrayType toArrayTypeFast() { return cast(ArrayType)cast(void*)this; }
	final AmbiguousArrayType toAmbiguousArrayTypeFast() { return cast(AmbiguousArrayType)cast(void*)this; }
	final StaticArrayType toStaticArrayTypeFast() { return cast(StaticArrayType)cast(void*)this; }
	final AAType toAATypeFast() { return cast(AAType)cast(void*)this; }
	final AAPair toAAPairFast() { return cast(AAPair)cast(void*)this; }
	final FunctionType toFunctionTypeFast() { return cast(FunctionType)cast(void*)this; }
	final DelegateType toDelegateTypeFast() { return cast(DelegateType)cast(void*)this; }
	final FunctionSetType toFunctionSetTypeFast() { return cast(FunctionSetType)cast(void*)this; }
	final StorageType toStorageTypeFast() { return cast(StorageType)cast(void*)this; }

	// Declaration
	final FunctionSet toFunctionSetFast() { return cast(FunctionSet)cast(void*)this; }
	final Variable toVariableFast() { return cast(Variable)cast(void*)this; }
	final Alias toAliasFast() { return cast(Alias)cast(void*)this; }
	final Function toFunctionFast() { return cast(Function)cast(void*)this; }
	final FunctionParam toFunctionParamFast() { return cast(FunctionParam)cast(void*)this; }
	final TypeOf toTypeOfFast() { return cast(TypeOf)cast(void*)this; }
	final NullType toNullTypeFast() { return cast(NullType)cast(void*)this; }
	final EnumDeclaration toEnumDeclarationFast() { return cast(EnumDeclaration)cast(void*)this; }
	final AutoType toAutoTypeFast() { return cast(AutoType)cast(void*)this; }
	final NoType toNoTypeFast() { return cast(NoType)cast(void*)this; }

	// Statements
	final ReturnStatement toReturnStatementFast() { return cast(ReturnStatement)cast(void*)this; }
	final BlockStatement toBlockStatementFast() { return cast(BlockStatement)cast(void*)this; }
	final AsmStatement toAsmStatementFast() { return cast(AsmStatement)cast(void*)this; }
	final IfStatement toIfStatementFast() { return cast(IfStatement)cast(void*)this; }
	final WhileStatement toWhileStatementFast() { return cast(WhileStatement)cast(void*)this; }
	final DoStatement toDoStatementFast() { return cast(DoStatement)cast(void*)this; }
	final ForStatement toForStatementFast() { return cast(ForStatement)cast(void*)this; }
	final ForeachStatement toForeachStatementFast() { return cast(ForeachStatement)cast(void*)this; }
	final LabelStatement toLabelStatementFast() { return cast(LabelStatement)cast(void*)this; }
	final ExpStatement toExpStatementFast() { return cast(ExpStatement)cast(void*)this; }
	final SwitchStatement toSwitchStatementFast() { return cast(SwitchStatement)cast(void*)this; }
	final SwitchCase toSwitchCaseFast() { return cast(SwitchCase)cast(void*)this; }
	final ContinueStatement toContinueStatementFast() { return cast(ContinueStatement)cast(void*)this; }
	final BreakStatement toBreakStatementFast() { return cast(BreakStatement)cast(void*)this; }
	final GotoStatement toGotoStatementFast() { return cast(GotoStatement)cast(void*)this; }
	final WithStatement toWithStatementFast() { return cast(WithStatement)cast(void*)this; }
	final SynchronizedStatement toSynchronizedStatementFast() { return cast(SynchronizedStatement)cast(void*)this; }
	final TryStatement toTryStatementFast() { return cast(TryStatement)cast(void*)this; }
	final ThrowStatement toThrowStatementFast() { return cast(ThrowStatement)cast(void*)this; }
	final ScopeStatement toScopeStatementFast() { return cast(ScopeStatement)cast(void*)this; }
	final PragmaStatement toPragmaStatementFast() { return cast(PragmaStatement)cast(void*)this; }
	final ConditionStatement toConditionStatementFast() { return cast(ConditionStatement)cast(void*)this; }
	final MixinStatement toMixinStatementFast() { return cast(MixinStatement)cast(void*)this; }
	final AssertStatement toAssertStatementFast() { return cast(AssertStatement)cast(void*)this; }

	// Expression
	final Constant toConstantFast() { return cast(Constant)cast(void*)this; }
	final BinOp toBinOpFast() { return cast(BinOp)cast(void*)this; }
	final Ternary toTernaryFast() { return cast(Ternary)cast(void*)this; }
	final Unary toUnaryFast() { return cast(Unary)cast(void*)this; }
	final Postfix toPostfixFast() { return cast(Postfix)cast(void*)this; }
	final ArrayLiteral toArrayLiteralFast() { return cast(ArrayLiteral)cast(void*)this; }
	final AssocArray toAssocArrayFast() { return cast(AssocArray)cast(void*)this; }
	final IdentifierExp toIdentifierExpFast() { return cast(IdentifierExp)cast(void*)this; }
	final Assert toAssertFast() { return cast(Assert)cast(void*)this; }
	final StringImport toStringImportFast() { return cast(StringImport)cast(void*)this; }
	final Typeid toTypeidFast() { return cast(Typeid)cast(void*)this; }
	final IsExp toIsExpFast() { return cast(IsExp)cast(void*)this; }
	final FunctionLiteral toFunctionLiteralFast() { return cast(FunctionLiteral)cast(void*)this; }
	final ExpReference toExpReferenceFast() { return cast(ExpReference)cast(void*)this; }
	final StructLiteral toStructLiteralFast() { return cast(StructLiteral)cast(void*)this; }
	final UnionLiteral toUnionLiteralFast() { return cast(UnionLiteral)cast(void*)this; }
	final ClassLiteral toClassLiteralFast() { return cast(ClassLiteral)cast(void*)this; }
	final TypeExp toTypeExpFast() { return cast(TypeExp)cast(void*)this; }
	final StoreExp toStoreExpFast() { return cast(StoreExp)cast(void*)this; }
	final StatementExp toStatementExpFast() { return cast(StatementExp)cast(void*)this; }
	final TokenExp toTokenExpFast() { return cast(TokenExp)cast(void*)this; }
	final VaArgExp toVaArgExpFast() { return cast(VaArgExp)cast(void*)this; }
	final PropertyExp toPropertyExpFast() { return cast(PropertyExp)cast(void*)this; }
	final BuiltinExp toBuiltinExpFast() { return cast(BuiltinExp)cast(void*)this; }
	final AccessExp toAccessExpFast() { return cast(AccessExp)cast(void*)this; }
	final RunExp toRunExpFast() { return cast(RunExp)cast(void*)this; }

	// Templates
	final TemplateInstance toTemplateInstanceFast() { return cast(TemplateInstance)cast(void*)this; }
	final TemplateDefinition toTemplateDefinitionFast() { return cast(TemplateDefinition)cast(void*)this; }


private:
	NodeType mNodeType;
	NodeID mUniqueId;
	static NodeID mUniqueIdCounter; // We are single threaded.
}

/**
 * A series of identifiers and dots referring to a declared item.
 *
 * @ingroup irNode
 */
class QualifiedName : Node
{
public:
	/// The last identifier is the module, any preceding identifiers are packages.
	Identifier[] identifiers;
	/// If true, this name starts with a dot.
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
		version (Volt) {
			this.identifiers = new old.identifiers[0 .. $];
		} else {
			this.identifiers = old.identifiers.dup;
		}
		this.leadingDot = old.leadingDot;
	}
}

/**
 * A single string that could be apart of ir.QualifiedName or
 * stand-alone node inside of the ir, referencing a declared item.
 *
 * @ingroup irNode
 */
class Identifier : Node
{
public:
	string value;

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

/**
 * Returns a string representing the node's nodeType.
 *
 * @ingroup irNode
 */
string nodeToString(Node node)
{
	return nodeToString(node.nodeType);
}

/**
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
	case AccessExp: return "AccessExp";
	case RunExp: return "RunExp";
	case TemplateInstance: return "TemplateInstance";
	case TemplateDefinition: return "TemplateDefinition";
	}
}

/**
 * For debugging helpers.
 */
string getNodeAddressString(Node node)
{
	version (Volt) {
		return toString(cast(void*)node);
	} else {
		return "0x" ~ toString(cast(void*)node);
	}
}

/**
 * For debugging helpers.
 */
string getNodeUniqueString(Node node)
{
	return toString(node.uniqueId);
}
