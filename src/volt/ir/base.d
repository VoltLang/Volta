// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.base;

public import volt.token.location : Location;
public import volt.token.token : Token, TokenType;

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
	StaticAssert,
	EmptyTopLevel,
	Condition,
	ConditionTopLevel,
	MixinFunction,
	MixinTemplate,
	UserAttribute,

	/* declaration.d */
	FunctionDecl,
	FunctionBody,
	PrimitiveType,
	TypeReference,
	PointerType,
	ArrayType,
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
	EmptyStatement,
	ConditionStatement,
	MixinStatement,
	AssertStatement,

	/* expression.d */
	Comma,
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
	ClassLiteral,
	TraitsExp,
	TypeExp,
	TemplateInstanceExp,
	StatementExp,
	TokenExp,
	VaArgExp,
}

/**
 * Common access levels used on declared functions, methods, classes,
 * interfaces, structs, enums and variables.
 *
 * @ingroup irNode
 */
enum Access {
	Public = TokenType.Public,
	Private = TokenType.Private,
	Package = TokenType.Package,
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
	Location location;

	/// Retrieve the NodeType for this Node.
	NodeType nodeType() { return mNodeType; }

protected:
	this(NodeType nt)
	{
		this.mNodeType = nt;
	}

private:
	NodeType mNodeType;

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
		string str;
		foreach (i, identifier; identifiers) {
			str ~= identifier.value;
			if (i < identifiers.length - 1) {
				str ~= ".";
			}
		}
		return str;
	}

	string[] strings()
	{
		string[] ret = new string[identifiers.length];

		foreach (i, identifier; identifiers) {
			ret[i] = identifier.value;
		}

		return ret;
	}

public:
	this() { super(NodeType.QualifiedName); }
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

	this(Identifier i)
	{
		this();
		value = i.value;
		location = i.location;
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
	case UserAttribute: return "UserAttribute";
	case Union: return "Union";
	case Enum: return "Enum";
	case EnumDeclaration: return "EnumDeclaration";
	case Attribute: return "Attribute";
	case StaticAssert: return "StaticAssert";
	case EmptyTopLevel: return "EmptyTopLevel";
	case MixinFunction: return "MixinFunction";
	case MixinTemplate: return "MixinTemplate";
	case Condition: return "Condition";
	case ConditionTopLevel: return "ConditionTopLevel";
	case FunctionDecl: return "FunctionDecl";
	case FunctionBody: return "FunctionBody";
	case FunctionSetType: return "FunctionSetType";
	case FunctionSet: return "FunctionSet";
	case PrimitiveType: return "PrimitiveType";
	case TypeReference: return "TypeReference";
	case PointerType: return "PointerType";
	case NullType: return "NullType";
	case ArrayType: return "ArrayType";
	case StaticArrayType: return "StaticArrayType";
	case AAType: return "AAType";
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
	case EmptyStatement: return "EmptyStatement";
	case ConditionStatement: return "ConditionStatement";
	case MixinStatement: return "MixinStatement";
	case AssertStatement: return "AssertStatement";
	case Comma: return "Comma";
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
	case ClassLiteral: return "ClassLiteral";
	case TraitsExp: return "TraitsExp";
	case TypeExp: return "TypeExp";
	case TemplateInstanceExp: return "TemplateInstanceExp";
	case StatementExp: return "StatementExp";
	case TokenExp: return "TokenExp";
	case VaArgExp: return "VaArgExp";
	}
}
