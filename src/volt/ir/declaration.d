// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.declaration;

import volt.ir.base;
import volt.ir.type;
import volt.ir.expression;
import volt.ir.statement;
import volt.ir.context;


/**
 * @defgroup irDecl IR Declaration Nodes
 *
 * Declarations associate names with types.
 *
 * Broadly speaking, there are variables and functions.
 * Both of which (essentially) associated a name with a typed
 * piece of memory.
 *
 * Aliases are different. While still associating a name
 * with a type, it's not an _instance_ of a type, but rather
 * a symbolic representation of the type (so the underlying
 * type may be changed transparently, or perhaps the real
 * type is long winded, or exposes implementation details).
 *
 * @ingroup irNode
 */

/**
 * Base class for all declarations.
 *
 * @ingroup irNode irDecl
 */
abstract class Declaration : Node
{
	enum Kind {
		Function = NodeType.Function,
		Variable = NodeType.Variable
	}

	@property Kind declKind() { return cast(Kind)nodeType; }
	this(NodeType nt) { super(nt); }
}

/**
 * Represents an instance of a type.
 *
 * A Variable has a type and a single name that is an
 * instance of that type. It may also have an expression
 * that represents a value to assign to it.
 *
 * @p Variables are mangled as type + parent names + name.
 *
 * @ingroup irNode irDecl
 */
class Variable : Declaration
{
public:
	enum Storage
	{
		None,  /// Not applicable (usually stack).
		Local,  /// Stored in TLS.
		Global,  /// Stored in the global data segment.
	}

public:
	/// The access level of this @p Variable, which determines how it interacts with other modules.
	Access access;

	/// The underlying @p Type this @p Variable is an instance of.
	Type type;
	/// The name of the instance of the type. This is not be mangled.
	string name;
	/// An optional mangled name for this Variable.
	string mangledName;
	
	/// An expression that is assigned to the instance if present.
	Exp assign;  // Optional.

	/// What storage this variable will be stored in. 
	Storage storage;

	// For exported symbols.
	Linkage linkage;

	bool isWeakLink;   ///< Only for global variables.

	bool isExtern; ///< Only for global variables.

	bool isRef;  ///< Will only true for some function parameters.

	/**
	 * Tells the backend to turn the storage Variable to the
	 * base of the reference or pointer type.
	 *
	 * Normally Variables hold storage for the type directly,
	 * so a int* holds a storage for a pointer. So the real
	 * type of the Variable is int** when we reference it in
	 * the backend. But it treats all references to that
	 * Variable as the pointer itself. So when you type:
	 *
	 * int *ptr;
	 * *ptr = 4;
	 *
	 * That is really:
	 *
	 * **ptr = 4;
	 *
	 * If this bool is set we the variable allocates the
	 * storage to be for the base type itself but still
	 * treats the pointer as a pointer type. You just can't
	 * assign to it nor can you get address of the storage.
	 *
	 * Mostly used for Classes, on typeid literals and on
	 * the this arguments to class functions.
	 */
	bool useBaseStorage;


public:
	this() { super(NodeType.Variable); }
	/// Construct a @p Variable with a given type and name.
	this(Type t, string name)
	{
		this();
		this.type = t;
		this.name = name;
	}
}

/**
 * An @p Alias associates names with a @p Type. Once declared, using that name is 
 * as using that @p Type directly.
 *
 * @ingroup irNode irDecl
 */
class Alias : Node
{
public:
	Access access;

	/// The @p Type names are associated with.
	Type type;
	/// The names to associate with the type.
	string name;


public:
	this() { super(NodeType.Alias); }
}

/**
 * A function is a block of code that takes parameters, and may return a value.
 * There may be additional implied context, depending on where it's defined.
 *
 * @p Functions are mangled as type + parent names + name.
 *
 * @ingroup irNode irDecl
 */
class Function : Declaration
{
public:
	/**
	 * Used to specify function type.
	 *
	 * Some types have hidden arguemnts, like the this arguement
	 * for member functions, constructors and destructors.
	 */
	enum Kind {
		Function,  ///< foo()
		Member,  ///< this.foo()
		LocalMember,  ///< Clazz.foo()
		GlobalMember,  ///< Clazz.foo()
		Constructor,  ///< auto foo = new Clazz()
		Destructor,  ///< delete foo
		LocalConstructor,  ///< local this() {}
		LocalDestructor,  ///< local ~this() {}
		GlobalConstructor,  ///< global this() {}
		GlobalDestructor,  ///< global ~this() {}
	}


public:
	Access access;  ///< defalt public.

	Kind kind;  ///< What kind of function.
	FunctionType type;  ///< Prototype.

	string name;  ///< Pre mangling.
	string mangledName;

	/**
	 * For use with the out contract.
	 *
	 * out (result)
	 *  ^ that's outParameter (optional).
	 */
	string outParameter;


	/// @todo Make these @p BlockStatements?
	BlockStatement inContract;  ///< Optional.
	BlockStatement outContract;  ///< Optional.
	BlockStatement _body;  ///< Optional.

	/// The @p Scope for the body of the function. @todo What about the contracts?
	Scope myScope;

	/// Optional this argument for member functions.
	Variable thisHiddenParameter;

	/**
	 * For functions generated by lowering passes.
	 * Causes multiple functions to be merged.
	 */
	bool isWeakLink;

	/**
	 * The middle-end uses this tag to determine if all the types 
	 * this function uses are well defined.
	 */
	bool defined;

	int vtableIndex = -1;  ///< If this is a member function, where in the vtable does it live?

public:
	this() { super(NodeType.Function); }
}
