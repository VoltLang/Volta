// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.expression;

import volt.ir.base;
import volt.ir.type;
import volt.ir.declaration;
import volt.ir.toplevel;
import volt.ir.statement;


/**
 * @defgroup irExp IR Expression Nodes
 *
 * Expressions compute a value based on an operation and one
 * or more values. Exp Nodes represent this. There are a lot
 * of expressions with wide ranging effects.
 *
 * Literals (integer constants, strings) are also expressions.
 *
 * An expression may or may not have a side effect depending
 * on the operation, and what is being operated on.
 * 
 * The expression nodes are mostly flat. Expressions contain
 * other expressions, but generally not a specific kind.
 *
 * @ingroup irNode
 */

/**
 * Base class for all expressions.
 *
 * @ingroup irNode irExp
 */
abstract class Exp : Node
{
public:

protected:
	this(NodeType nt) { super(nt); }
}

/**
 * A ternary expression is a short hand if statement in the form of an expression. 
 * 
 * condition ? ifTrue : ifFalse
 *
 * is equivalent to calling a function with a body of
 *
 * if (condition) return ifTrue;
 * else return ifFalse;
 *
 * @ingroup irNode irExp
 */
class Ternary : Exp
{
public:
	Exp condition;  ///< The condition to test.
	Exp ifTrue;  ///< Evaluate and return this if condition is true.
	Exp ifFalse;  ///< Evaluate and return this if condition is false.

public:
	this() { super(NodeType.Ternary); }
}

/**
 * A BinOp is an operation the operates on two expressions with a given 
 * operation.
 *
 * This includes assignment. The composite assign operators (e.g. AddAssign, +=)
 * will be lowered out before the backend sees them.
 *
 * @ingroup irNode irExp
 */
class BinOp : Exp
{
public:
	// Arranged in precedence order, lowest to highest.
	enum Op
	{
		None,
		Assign,
		AddAssign,
		SubAssign,
		MulAssign,
		DivAssign,
		ModAssign,
		AndAssign,
		OrAssign,
		XorAssign,
		CatAssign,
		LSAssign,  // <<=
		SRSAssign,  // >>=
		RSAssign, // >>>=
		PowAssign,
		OrOr,
		AndAnd,
		Or,
		Xor,
		And,
		Equal,
		NotEqual,
		Is,
		NotIs,
		Less,
		LessEqual,
		GreaterEqual,
		Greater,
		In,
		NotIn,
		LS,  // <<
		SRS, // >>
		RS,  // >>>
		Add,
		Sub,
		Cat,
		Mul,
		Div,
		Mod,
		Pow
	}

public:
	Op op;  ///< The operation to perform.
	Exp left;  ///< The left hand side of the expression.
	Exp right;  ///< The right hand side of the expression.

public:
	this() { super(NodeType.BinOp); }
}

/**
 * A Unary operation is prepended to the back of an expression.
 *
 * @ingroup irNode irExp
 */
class Unary : Exp
{
public:
	enum Op
	{
		None,
		AddrOf,
		Increment,
		Decrement,
		Dereference,
		Minus,
		Plus,
		Not,
		Complement,
		New,
		TypeIdent,  // (Type).Identifier
		Cast,
	}

public:
	Op op;
	Exp value;

	bool hasArgumentList;
	Type type;  // with Cast and New.
	Exp[] argumentList;  // With new StringObject("foo", "bar");

public:
	this() { super(NodeType.Unary); }
	this(Type n, Exp e) { super(NodeType.Unary); location = e.location; op = Op.Cast; value = e; type = n; }
}

/**
 * A postfix operation is appended to an expression.
 *
 * @ingroup irNode irExp
 */
class Postfix : Exp
{
public:
	enum Op
	{
		None,
		Identifier,
		Increment,
		Decrement,
		Call,
		Index,
		Slice,
		CreateDelegate,
	}

	enum TagKind
	{
		None,
		Ref,
		Out,
	}

public:
	Op op;
	Exp child;  // What the op is operating on.
	Exp[] arguments;
	TagKind[] argumentTags;
	Identifier identifier;  // op == Identifier
	ExpReference memberFunction;
	bool isImplicitPropertyCall;

public:
	this() { super(NodeType.Postfix); }
}

/**
 * A Constant is a literal value of a given type.
 *
 * @ingroup irNode irExp
 */
class Constant : Exp
{
public:
	union
	{
		int _int;
		uint _uint;
		long _long;
		ulong _ulong;
		float _float;
		double _double;
		bool _bool;
		void* _pointer;
	}
	string _string;
	bool isNull;  // Turns out checking for non-truth can be hard.
	void[] arrayData;
	Type type;

public:
	this() { super(NodeType.Constant); }
}

/**
 * Represents an array literal. Contains a list of expressions with
 * (if semantically sound) a common type.
 *
 * @ingroup irNode irExp
 */
class ArrayLiteral : Exp
{
public:
	Exp[] values;
	Type type;  ///< The type of the array. e.g. [1, 2, 3], type would be int[], not int.

public:
	this() { super(NodeType.ArrayLiteral); }
}

class AAPair : Node
{
public:
	Exp key;
	Exp value;

public:
	this() { super(NodeType.AAPair); }
	this(Exp key, Exp value)
	{
		this();
		this.key = key;
		this.value = value;
	}
}

/**
 * Represents an associative array literal -- a list of
 * key/value pairs.
 *
 * @ingroup irNode irExp
 */
class AssocArray : Exp
{
public:
	AAPair[] pairs;
	Type type;  ///< The type of the associative array.

public:
	this() { super(NodeType.AssocArray); }
}

/**
 * Represents a single identifier. Replaced with ExpReference in a pass.
 *
 * @ingroup irNode irExp
 */
class IdentifierExp : Exp
{
public:
	bool globalLookup;  // Leading dot.
	string value;

	Node type;

public:
	this() { super(NodeType.IdentifierExp); }
	this(string s)
	{
		this();
		value = s;
	}
}

/**
 * An Assert checks that a condition is true, and dies with an optional message if not.
 *
 * @ingroup irNode irExp
 */
class Assert : Exp
{
public:
	Exp condition;
	Exp message;  // Optional.

public:
	this() { super(NodeType.Assert); }
}

/**
 * A StringImport creates a string literal from a file on disk at compile time.
 *
 * @ingroup irNode irExp
 */
class StringImport : Exp
{
public:
	Exp filename;

public:
	this() { super(NodeType.StringImport); }
}

/**
 * The typeid expression returns the typeinfo of a given type or expression.
 *
 * @ingroup irNode irExp
 */
class Typeid : Exp
{
public:
	// One of these will be non empty.
	Exp exp;  // Optional.
	Type type;  // Optional.
	string ident;  // Optional.

public:
	this() { super(NodeType.Typeid); }
}

/**
 * The is expression is a bit of a swiss army knife. 
 * It can be simply used to determine whether a given type is well-formed,
 * or if a given type is a certain other type, or can be converted into another
 * type.
 *
 * Mostly useful for generic code. Not to be confused with the BinOp 'is' which
 * checks the identity of pointers and things.
 *
 * @ingroup irNode irExp
 */
class IsExp : Exp
{
public:
	enum Specialisation
	{
		None,
		Type,
		Struct = TokenType.Struct,
		Union = TokenType.Union,
		Class = TokenType.Class,
		Interface = TokenType.Interface,
		Enum = TokenType.Enum,
		Function = TokenType.Function,
		Delegate = TokenType.Delegate,
		Super = TokenType.Super,
		Const = TokenType.Const,
		Immutable = TokenType.Immutable,
		Inout = TokenType.Inout,
		Shared = TokenType.Shared,
		Return = TokenType.Return,
	}

	enum Comparison
	{
		None,
		Implicit,  // is(T : int)
		Exact,  // is(T == int)
	}

public:
	Type type;
	string identifier;  // Optional.
	Specialisation specialisation;
	Type specType;  // If specialisation == Type.
	Comparison compType;

public:
	this() { super(NodeType.IsExp); }
}

class FunctionParameter : Node
{
public:
	Type type;
	string name;

public:
	this() { super(NodeType.FunctionParam); }
}

/**
 * A function literal can define a normal function, or a delegate (a function with context).
 * There are multiple ways to define these but the long hand way is
 *   int function(int a, int b) { return a + b; }
 * Defines a function that takes two integers and returns them added up.
 *   int delegate(int a, int b) { return a + b + c; }
 * Is the same, except it has access to the outer scope's variables.
 *
 * @ingroup irNode irExp
 */
class FunctionLiteral : Exp
{
public:
	bool isDelegate;
	Type returnType;  // Optional.
	FunctionParameter[] params;
	BlockStatement block;

	string singleLambdaParam;  // Optional. (<a> => a + 1)
	Exp lambdaExp;  // Optional. (a => <a + 1>;)

public:
	this() { super(NodeType.FunctionLiteral); }
}

/**
 * An ExpReference replaces chained postfix look ups with the result of the lookup.
 * A cache that is inserted later, in other words.
 *
 * @ingroup irNode irExp
 */
class ExpReference : Exp
{
public:
	string[] idents;
	Declaration decl;
	bool rawReference;  ///< A raw get to a function to bypass @property.
	/**
	 * When dealing with references to parameters in a nested function,
	 * they need to be rewritten to lookup through a nested context,
	 * except when assigning their value to the context struct. This flag
	 * tells the semantic phase to leave this particular reference alone
	 * for that purpose.
	 */
	bool doNotRewriteAsNestedLookup;

public:
	this() { super(NodeType.ExpReference); }
}

/// A StructLiteral is an expression form of a struct.
class StructLiteral : Exp
{
public:
	Exp[] exps;
	Type type;  /// Filled in Later.

public:
	this() { super(NodeType.StructLiteral); }
}

/// A ClassLiteral is a compiler internal expression form of a class.
class ClassLiteral : Exp
{
public:
	Exp[] exps;  ///< Values for the fields in the class.
	Type type;  ///< The class this literal represents.

	/// See Variable.useBaseStorage, should be set for literals.
	bool useBaseStorage;

public:
	this() { super(NodeType.ClassLiteral); }
}

class TraitsExp : Exp
{
public:
	enum Op
	{
		GetAttribute,
	}

public:
	Op op;

	QualifiedName target;
	QualifiedName qname;

public:
	this() { super(NodeType.TraitsExp); }
}

/**
 * A TypeExp is used when a primitive type is used in an expression.
 * This is currently limited to <primitive>.max/min and (void*).max/min.
 *
 * @ingroup irNode irExp
 */
class TypeExp : Exp
{
public:
	Type type;

public:
	this() { super(NodeType.TypeExp); }
}

/**
 * A TemplateInstanceExp represents an instantiation of a template
 * with explicit type parameters.
 *
 * @ingroup irNode irExp
 */
class TemplateInstanceExp : Exp
{
public:
	string name;
	Type[] types;

public:
	this() { super(NodeType.TemplateInstanceExp); }
}

/**
 * A StatementExp is a internal expression for inserting statements
 * into a expression. Note that this is not a function and executes
 * the statements just as if they where inserted in the BlockStatement
 * that the StatementExp is in. Meaning any ReturnStatement will
 * return the current function not this StatementExp.
 *
 * @ingroup irNode irExp
 */
class StatementExp : Exp
{
public:
	Node[] statements; ///< A list of statements to be executed.
	Exp exp; ///< The value of the StatementExp

public:
	this() { super(NodeType.StatementExp); }
}

/**
 * Expression that corresponds to what was once special tokens.
 * __FUNCTION__, __PRETTY_FUNCTION__, __FILE__, and __LINE.
 *
 * @ingroup irNode irExp
 */
class TokenExp : Exp
{
public:
	enum Type
	{
		Function, ///< Just the function name. (e.g. math.add)
		PrettyFunction,  ///< Full signature. (e.g. int math.add(int a, int b))
		File,  ///< Current file. (e.g. foo.volt)
		Line,  ///< Current line number. (e.g. 32)
	}

	Type type;

public:
	this(TokenExp.Type type)
	{
		super(NodeType.TokenExp);
		this.type = type;
	}
}

/**
 * Expression that assists in working with varargs.
 *
 * @ingroup irNode irExp
 */
class VaArgExp : Exp
{
public:
	Exp arg;
	Type type;

public:
	this() { super(NodeType.VaArgExp); }
}

