// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.declaration;

import volt.ir.base;
import volt.ir.type;
import volt.ir.expression;
import volt.ir.statement;
import volt.ir.context;
import volt.ir.toplevel;


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
		Variable = NodeType.Variable,
		EnumDeclaration = NodeType.EnumDeclaration,
		FunctionSet = NodeType.FunctionSet,
		FunctionParam = NodeType.FunctionParam,
	}
	Attribute[] userAttrs;
	string oldname;  // Optional. Used for righting lookups of renamed identifiers in nested functions.

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
		Invalid,
		Field, /// Member of a struct/class.
		Function, /// Variable in a function.
		Nested,  /// Accessed in a nested function.
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

	bool isResolved;   ///< Has the extyper checked this variable.

	bool isWeakLink;   ///< Only for global variables.

	bool isExtern; ///< Only for global variables.

	bool isOut;  ///< The type will be a ref storage type if this is set.

	bool hasBeenDeclared;  ///< Has this variable been declared yet? (only useful in extyper)

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
	bool resolved;

	/**
	 * The names to associate with the alias.
	 *
	 * alias >name< = ...;
	 */
	string name;

	/**
	 * The @p Type names are associated with.
	 *
	 * alias name = const(char)[];
	 */
	Type type;

	/**
	 * This alias is a pure rebind of a name,
	 * for when the parser doesn't know what it is.
	 *
	 * alias name = >.qualified.name<;
	 */
	QualifiedName id;

	/**
	 * Needed for resolving.
	 */
	Store store;


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
		Invalid,
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

	Scope myScope; ///< Needed for params

	Kind kind;  ///< What kind of function.
	FunctionType type;  ///< Prototype.
	FunctionParam[] params;
	Function[] nestedFunctions;

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

	/// Optional this argument for member functions.
	Variable thisHiddenParameter;
	/// Contains the context for nested functions.
	Variable nestedHiddenParameter;
	/// As above, but includes the initial declaration in the non nested parent.
	Variable nestedVariable;
	/// Variables renamed for nested shadowing.
	Variable[] renamedVariables;

	Struct nestStruct;

	/**
	 * For functions generated by lowering passes.
	 * Causes multiple functions to be merged.
	 */
	bool isWeakLink;

	int vtableIndex = -1;  ///< If this is a member function, where in the vtable does it live?

	/// True if this function has an explicit call to super in
	bool explicitCallToSuper;

	/// Will be turned into a function pointer.
	bool loadDynamic;

	bool isMarkedOverride;

	bool isAbstract;

public:
	this() { super(NodeType.Function); }
}

class EnumDeclaration : Declaration
{
	Type type;

	Exp assign;
	string name;
	EnumDeclaration prevEnum;
	bool resolved;

public:
	this() { super(NodeType.EnumDeclaration); }
}

/**
 * Represents multiple functions associated with a single name.
 *
 * Contains the ExpReference that this set is associated with
 * so that it can be transparently updated to point at the
 * selected function.
 *
 * @ingroup irNode irDecl
 */
class FunctionSet : Declaration
{
public:
	Function[] functions;
	ExpReference reference;

public:
	this() { super(NodeType.FunctionSet); }

	@property FunctionSetType type()
	{
		auto t = new FunctionSetType();
		t.location = location;
		t.set = this;
		return t;
	}

	/**
	 * Update reference to indicate function set has been resolved.
	 * Returns the function passed to it.
	 */
	Function resolved(Function fn)
	{
		assert(reference !is null);
		reference.decl = fn;
		functions = null;
		reference = null;
		return fn;
	}
}

/**
 * Represents a parameter to a function.
 *
 * Indirectly references the type which is on the Callable,
 * and just contains the metadata parameters have (name, assign. etc).
 *
 * @ingroup irNode irDecl
 */
class FunctionParam : Declaration
{
public:
	Function fn;
	size_t index;
	Exp assign;
	string name;  // Optional.
	bool hasBeenNested;  ///< Has this parameter been nested into a nested context struct?

public:
	this()
	{
		super(NodeType.FunctionParam);
	}

	@property Type type()
	{
		assert(fn !is null);
		return fn.type.params[index];
	}
}
