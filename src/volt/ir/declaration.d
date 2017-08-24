// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.declaration;

import volt.errors;
import volt.ir.base;
import volt.ir.type;
import volt.ir.expression;
import volt.ir.statement;
import volt.ir.context;
import volt.ir.toplevel;
import volt.ir.templates;

import volt.util.dup;


/*!
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

/*!
 * Base class for all declarations.
 *
 * @ingroup irNode irDecl
 */
abstract class Declaration : Node
{
	enum Kind {
		Invalid,
		Function = NodeType.Function,
		Variable = NodeType.Variable,
		EnumDeclaration = NodeType.EnumDeclaration,
		FunctionSet = NodeType.FunctionSet,
		FunctionParam = NodeType.FunctionParam,
	}
	Attribute[] annotations;

	@property Kind declKind() { return cast(Kind)nodeType; }
	this(NodeType nt) { super(nt); }

	this(NodeType nt, Declaration old)
	{
		super(nt, old);
		this.annotations = old.annotations.dup();
	}
}

/*!
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
		Field, //!< Member of a struct/class.
		Function, //!< Variable in a function.
		Nested,  //!< Accessed in a nested function.
		Local,  //!< Stored in TLS.
		Global,  //!< Stored in the global data segment.
	}

	static string storageToString(Storage s)
	{
		final switch (s) with (Storage) {
		case Invalid:  return "invalid";
		case Field:    return "field";
		case Function: return "function";
		case Nested:   return "nested";
		case Local:    return "local";
		case Global:   return "global";
		}
	}

public:
	//! Has the extyper checked this variable.
	bool isResolved;

	//! The access level of this @p Variable, which determines how
	//! it interacts with other modules.
	Access access = Access.Public;

	//! The underlying @p Type this @p Variable is an instance of.
	Type type;
	//! The name of the instance of the type. This is not be mangled.
	string name;
	//! An optional mangled name for this Variable.
	string mangledName;
	
	//! An expression that is assigned to the instance if present.
	Exp assign;  // Optional.

	//! What storage this variable will be stored in. 
	Storage storage;

	// For exported symbols.
	Linkage linkage;

	/*!
	 * Only for global variables.
	 *
	 * Can the linker merge any symbol of the same name into one.
	 */
	bool isMergable;

	bool isExtern;  //!< Only for global variables.

	bool isOut;  //!< The type will be a ref storage type if this is set.

	bool hasBeenDeclared;  //!< Has this variable been declared yet? (only useful in extyper)

	/*!
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

	/*!
	 * This variable is initialized not by the assign but
	 * by the backend. Mostly used for catch statements.
	 */
	bool specialInitValue;

	/*!
	 * Tells the backend to not zero out this variable.
	 */
	bool noInitialise;

public:
	this() { super(NodeType.Variable); }
	//! Construct a @p Variable with a given type and name.
	this(Type t, string name)
	{
		this();
		this.type = t;
		this.name = name;
	}

	this(Variable old)
	{
		super(NodeType.Variable, old);
		this.isResolved = old.isResolved;
		this.access = old.access;
		this.type = old.type;
		this.name = old.name;
		this.mangledName = old.mangledName;
		this.assign = old.assign;
		this.storage = old.storage;
		this.linkage = old.linkage;
		this.isMergable = old.isMergable;
		this.isExtern = old.isExtern;
		this.isOut = old.isOut;
		this.hasBeenDeclared = old.hasBeenDeclared;
		this.useBaseStorage = old.useBaseStorage;
		this.specialInitValue = old.specialInitValue;
	}
}

/*!
 * An @p Alias associates names with a @p Type. Once declared, using that name is 
 * as using that @p Type directly.
 *
 * @ingroup irNode irDecl
 */
class Alias : Node
{
public:
	bool isResolved;

	//! Usability from other modules.
	Access access = Access.Public;

	/*!
	 * The names to associate with the alias.
	 *
	 * alias >name< = ...;
	 */
	string name;

	Attribute externAttr;  //!< Non null type.

	/*!
	 * The @p Type names are associated with.
	 *
	 * alias name = const(char)[];
	 */
	Type type;

	/*!
	 * This alias is a pure rebind of a name,
	 * for when the parser doesn't know what it is.
	 *
	 * alias name = >.qualified.name<;
	 */
	QualifiedName id;

	/*!
	 * Where are we looking for the symbol.
	 * @{
	 */
	Scope lookScope;
	Module lookModule;
	/*!
	 * @}
	 */

	/*!
	 * Needed for resolving.
	 */
	Store store;


	Exp templateInstance;  //!< Not with id. Optional.

public:
	this() { super(NodeType.Alias); }

	this(Alias old)
	{
		super(NodeType.Alias, old);
		this.isResolved = old.isResolved;
		this.access = old.access;
		this.name = old.name;
		this.externAttr = old.externAttr;
		this.type = old.type;
		this.id = old.id;
		this.lookScope = old.lookScope;
		this.lookModule = old.lookModule;
		this.templateInstance = old.templateInstance;
	}
}

/*!
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
	/*!
	 * Used to specify function type.
	 *
	 * Some types have hidden arguments, like the this argument
	 * for member functions, constructors and destructors.
	 */
	enum Kind {
		Invalid,
		Function,  //!< foo()
		Member,  //!< this.foo()
		LocalMember,  //!< Clazz.foo()
		GlobalMember,  //!< Clazz.foo()
		Constructor,  //!< auto foo = new Clazz()
		Destructor,  //!< delete foo
		LocalConstructor,  //!< local this() {}
		LocalDestructor,  //!< local ~this() {}
		GlobalConstructor,  //!< global this() {}
		GlobalDestructor,  //!< global ~this() {}
		Nested,  //!< void aFunction() { void foo() {} }
		GlobalNested,  //!< void aFunction() { global void foo() {} }
	}


public:
	//! Has the extyper checked this function.
	bool isResolved;
	//! Has the extyper checked the body of this function.
	bool isActualized;

	//! Usability from other modules.
	Access access = Access.Public;

	Scope myScope; //!< Needed for params

	Kind kind;  //!< What kind of function.
	FunctionType type;  //!< Prototype.
	FunctionParam[] params;
	Function[] nestedFunctions;

	//! The various scope (exit/success/failures) turned into inline functions.
	//! @{
	Function[] scopeSuccesses;
	Function[] scopeExits;
	Function[] scopeFailures;
	//! @}

	string name;  //!< Pre mangling.
	string mangledName;

	/*!
	 * For use with the out contract.
	 *
	 * out (result)
	 *  ^ that's outParameter (optional).
	 */
	string outParameter;


	//! @todo Make these @p BlockStatements?
	BlockStatement inContract;  //!< Optional.
	BlockStatement outContract;  //!< Optional.
	BlockStatement _body;  //!< Optional.

	//! Optional this argument for member functions.
	Variable thisHiddenParameter;
	//! Contains the context for nested functions.
	Variable nestedHiddenParameter;
	//! As above, but includes the initial declaration in the non nested parent.
	Variable nestedVariable;
	//! Optional sink argument for functions that contain runtime composable strings.
	Variable composableSinkVariable;

	Struct nestStruct;

	/*!
	 * For functions generated by lowering passes.
	 * Causes multiple functions to be merged.
	 */
	bool isMergable;

	int vtableIndex = -1;  //!< If this is a member function, where in the vtable does it live?
	//! Will be turned into a function pointer.
	bool loadDynamic;

	bool isMarkedOverride;

	/*!
	 * Marks this method as marked as overriding an interface method.
	 * (So don't do the things you'd normally do to an overriding method.)
	 */
	bool isOverridingInterface;

	bool isAbstract;
	bool isFinal;

	/*!
	 * Makes the ExTyper automatically set the correct return type
	 * based on the returned expression.
	 */
	bool isAutoReturn;

	/*!
	 * Is this a function a lowered construct, like scope.
	 * @{
	 */
	bool isLoweredScopeExit;
	bool isLoweredScopeFailure;
	bool isLoweredScopeSuccess;
	//! @}

	TemplateInstance templateInstance;  //!< Optional. Non-null if this is a template instantiation.


public:
	this() { super(NodeType.Function); }

	this(Function old)
	{
		super(NodeType.Function, old);
		this.isResolved = old.isResolved;
		this.isActualized = old.isActualized;
		this.access = old.access;
		this.myScope = old.myScope;
		this.kind = old.kind;
		this.type = old.type;
		this.params = old.params.dup();
		this.nestedFunctions = old.nestedFunctions.dup();
		this.scopeSuccesses = old.scopeSuccesses.dup();
		this.scopeExits = old.scopeExits.dup();
		this.scopeFailures = old.scopeFailures.dup();
		this.name = old.name;
		this.mangledName = old.mangledName;
		this.outParameter = old.outParameter;
		this.inContract = old.inContract;
		this.outContract = old.outContract;
		this._body = old._body;
		this.thisHiddenParameter = old.thisHiddenParameter;
		this.nestedHiddenParameter = old.nestedHiddenParameter;
		this.nestedVariable = old.nestedVariable;
		this.composableSinkVariable = old.composableSinkVariable;
		this.nestStruct = old.nestStruct;
		this.isMergable = old.isMergable;
		this.vtableIndex = old.vtableIndex;
		this.loadDynamic = old.loadDynamic;
		this.isMarkedOverride = old.isMarkedOverride;
		this.isOverridingInterface = old.isOverridingInterface;
		this.isAbstract = old.isAbstract;
		this.isFinal = old.isFinal;
		this.isAutoReturn = old.isAutoReturn;
		this.isLoweredScopeExit = old.isLoweredScopeExit;
		this.isLoweredScopeFailure = old.isLoweredScopeFailure;
		this.isLoweredScopeSuccess = old.isLoweredScopeSuccess;
		this.templateInstance = old.templateInstance;
	}
}

class EnumDeclaration : Declaration
{
	Type type;

	Exp assign;
	string name;
	EnumDeclaration prevEnum;
	bool resolved;
	Access access;
	bool isStandalone;  // enum A = <blah> style declaration.

public:
	this() { super(NodeType.EnumDeclaration); }

	this(EnumDeclaration old)
	{
		super(NodeType.EnumDeclaration, old);
		this.type = old.type;

		this.assign = old.assign;
		this.name = old.name;
		this.prevEnum = old.prevEnum;
		this.resolved = old.resolved;
		this.isStandalone = old.isStandalone;
	}
}

/*!
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
	ExpReference reference;  //!< For assigning an overloaded function to a delegate.

public:
	this() { super(NodeType.FunctionSet); }

	this(FunctionSet old)
	{
		super(NodeType.FunctionSet, old);
		this.functions = old.functions.dup();
		this.reference = old.reference;
	}

	@property FunctionSetType type()
	{
		auto t = new FunctionSetType();
		t.loc = loc;
		t.set = this;
		return t;
	}

	/*!
	 * Update reference to indicate function set has been resolved.
	 * Returns the function passed to it.
	 */
	Function resolved(Function func)
	{
		if (reference !is null) {
			reference.decl = func;
		}
		functions = null;
		reference = null;
		return func;
	}
}

/*!
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
	Function func;
	size_t index;
	Exp assign;
	string name;  // Optional.
	bool hasBeenNested;  //!< Has this parameter been nested into a nested context struct?

public:
	this()
	{
		super(NodeType.FunctionParam);
	}

	this(FunctionParam old)
	{
		super(NodeType.FunctionParam, old);
		this.func = old.func;
		this.index = old.index;
		this.assign = old.assign;
		this.name = old.name;
		this.hasBeenNested = old.hasBeenNested;
	}

	@property Type type()
	{
		assert(func !is null);
		return func.type.params[index];
	}
}
