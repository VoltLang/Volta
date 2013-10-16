// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.toplevel;

import volt.ir.base;
import volt.ir.type;
import volt.ir.context;
import volt.ir.expression;
import volt.ir.declaration;
import volt.ir.statement;

/**
 * @defgroup irTopLevel IR TopLevel Nodes
 *
 * Top level nodes are Nodes relating to the the module system.
 * They either are part of the machinery that it works with
 * (modules, imports) or define types and friends that work with 
 * the module system (structs, classes), or simply things that
 * can only live in top level contexts (e.g. unittest blocks).
 *
 * As you can see, it's a fairly nebulous group. There are things
 * here that could be arguably placed elsewhere (an Enum is a Type,
 * for instance). Or things that are elsewhere could arguably belong
 * here! (Functions, as an example). 
 *
 * The reason for this nebulousity is that Volt is a child of
 * the curly brace languages -- particularly D, and through that
 * heritage, C++ and C. In C there was a very strict line about
 * what could be defined where, and resulting languages have stretched
 * that somewhat -- functions and structs inlined inside of functions,
 * for example, a place where traditionally only statements reside.
 *
 * So perhaps not the most elegant system, but usability trumps
 * elegance, much to the chagrin of architect astronauts everywhere.
 *
 * @ingroup irNode
 */

/**
 * The toplevelest node.
 *
 * In Volt, there is no truly global scope, as in C or C++
 * (the object module is the closest thing, and by and large
 * the user can't change that), everything can be disambiguated
 * by its module. This means things primitive forms of namespacing
 * found in C (glGetString vs gl.GetString, for example) are not
 * needed (except when interfacing with C, of course) and ambiguous
 * names are not a major issue.
 *
 * A module has name. Zero or more package names, followed by the
 * name of the module. This name must be unique for any given run
 * of the compiler -- two modules cannot have the same name.
 *
 * The module contains the declarations that other modules can
 * retrieve (or not retrieve, depending on access levels).
 *
 * @ingroup irNode irTopLevel
 */
class Module : Node
{
public:
	QualifiedName name; ///< Name used for mangling.
	TopLevelBlock children; ///< Toplevel nodes.

	/**
	 * Scope for this module.
	 *
	 * Does not contain any imports public or otherwise.
	 */
	Scope myScope;

	/**
	 * Has phase 1 be started on this module.
	 */
	bool hasPhase1;
	/**
	 * Has phase 2 be started on this module.
	 */
	bool hasPhase2;

	bool gathered;

public:
	this() { super(NodeType.Module); }
}

/**
 * A TopLevelBlock contains a series of nodes, appropriate
 * for things like modules, classes, structs, and so on.
 *
 * This allows visitors to handle such things uniformly when
 * needed.
 */
class TopLevelBlock : Node
{
public:
	Node[] nodes;

public:
	this() { super(NodeType.TopLevelBlock); }
}

/**
 * An Import adds a module to the search path of identifiers
 * inside the module it's in.
 *
 * For example. In a module with no imports, the symbol 'foo'
 * is only looked for in the current module -- if it's found,
 * there's no problem.
 * 
 * If we add an import, when the symbol 'foo' is looked up,
 * nothing changes if 'foo' is found in the module with the
 * import -- local declarations trump anything found in imports.
 * This is to prevent changes in external modules affecting
 * the behaviour of a program silently.
 *
 * However, if there is no local 'foo', then all imported modules are
 * modules are searched for accessible 'foo' symbols. If one is found,
 * it is used, if more than one is found -- it is an error. This can
 * be resolved by the user defining a local alias of that symbol
 * (see 'local declarations trump import', above for why that works),
 * or explicitly importing symbols, or making a module have to be 
 * accessed in long form (the.module.foo vs just foo).
 *
 * @ingroup irNode irTopLevel
 */
class Import : Node
{
public:
	/// public, private, package or protected.
	Access access = Access.Private;

	/// Optional
	bool isStatic;

	/// import <a>
	QualifiedName name;

	/// Optional, import @<foo> = a
	Identifier bind;

	/// Optional, import a : <b = c, d>
	Identifier[2][] aliases;

	/// This points at the imported module -- filled in by ImportResolver.
	Module targetModule;


public:
	this() { super(NodeType.Import); }
}

/**
 * Attributes apply different behaviours and access levels
 * to one or more top level nodes. These are lowered onto the
 * object by the attribremoval pass.
 *
 * @ingroup irNode irTopLevel
 */
class Attribute : Node
{
public:
	/**
	 * Used to specify the exact sort of attribute.
	 */
	enum Kind
	{
		LinkageVolt,
		LinkageC,
		LinkageCPlusPlus,
		LinkageD,
		LinkageWindows,
		LinkagePascal,
		LinkageSystem,
		LoadDynamic,
		Align,
		Deprecated,
		Private,
		Protected,
		Package,
		Public,
		Export,
		Static,
		Extern,
		Final,
		Synchronized,
		Override,
		Abstract,
		Const,
		Auto,
		Scope,
		Global,
		Local,
		Shared,
		Immutable,
		Inout,
		Disable,
		Property,
		Trusted,
		System,
		Safe,
		NoThrow,
		Pure,
		UserAttribute,
		MangledName,
	}


public:
	/// What kind of attribute.
	Kind kind;

	TopLevelBlock members;

	QualifiedName userAttributeName;  ///< Optional.
	Exp[] arguments;  ///< If kind == UserAttribute or MangledName.
	UserAttribute userAttribute;  ///< Filled in by the exptyper.

	/// Only if type == Align.
	int alignAmount;

public:
	this() { super(NodeType.Attribute); }
}

/**
 * Aggregate is a base class for Struct, Union & Class.
 */
abstract class Aggregate : Type
{
public:
	string name; ///< Unmangled name of the NamedType.
	Access access; ///< default public.

	Scope myScope; ///< Context for this NamedType.

	Variable typeInfo;  ///< Filled in by the semantic pass.

	Attribute[] userAttrs;

	TopLevelBlock members; ///< Toplevel nodes.

	bool isResolved;
	bool isActualized;

public:
	this(NodeType nt) { super(nt); }
}

/**
 * Java style class declaration. Classes enable polymorphism,
 * and are always accessed through opaque references (to prevent
 * slicing -- look it up!)
 *
 * @p Classes are mangled as "C" + @p name.
 *
 * @ingroup irNode irTopLevel irType irDecl
 */
class Class : Aggregate
{
public:
	QualifiedName parent;  //< Optional.
	QualifiedName[] interfaces;  //< Optional.

	Function[] userConstructors;
	Struct vtableStruct;
	Variable vtableVariable;
	Class parentClass;  ///< Filled in by the typeverifier.

	/// How a lowered class will look internally.
	Struct layoutStruct;

	/// Is this the one true 'Object' to rule them all?
	bool isObject;

	bool isAbstract;

public:
	this() { super(NodeType.Class); }
}

/**
 * Java style interface declaration. 
 * An interface defines multiple functions that an implementing
 * class must define. A class can inherit from multiple interfaces,
 * and can be treated as an instance of any one of them. 
 *
 * @ingroup irNode irTopLevel irType irDecl
 */
class _Interface : Type
{
public:
	Access access; ///< default public.

	Scope myScope; ///< Context for this Interface.

	string name; ///< Unmangled name of the Interface.
	QualifiedName[] interfaces; ///< Super interfaces to this.
	TopLevelBlock members; ///< Toplevel nodes.
	Attribute[] userAttrs;

public:
	this() { super(NodeType.Interface); }
}

/**
 * C style union.
 * Structs are a POD data type, and should be binary compatible
 * with the same union as defined by your friendly neighbourhood
 * C compiler.
 *
 * @p Union are mangled as "U" + @p name.
 *
 * @ingroup irNode irTopLevel irType irDecl
 */
class Union : Aggregate
{
public:
	int totalSize; // Total size in memory.

public:
	this() { super(NodeType.Union); }
}

/**
 * C style struct.
 * Structs are a POD data type, and should be binary compatible
 * with the same struct as defined by your friendly neighbourhood
 * C compiler. 
 *
 * @p Structs are mangled as "S" + @p name.
 *
 * @ingroup irNode irTopLevel irType irDecl
 */
class Struct : Aggregate
{
public:
	Node loweredNode;  ///< If not null, this struct was lowered from this.

public:
	this() { super(NodeType.Struct); }
}


/**
 * C style Enum.
 * Enums create symbols that are associated with compile
 * time constants. By default, they are enumerated with
 * ascending numbers, hence the name.
 *
 * @p Enums are mangled as "E" + @p name.
 *
 * @ingroup irNode irTopLevel irType irDecl
 */
class Enum : Type
{
public:
	Access access; ///< default public.
	string name;  ///< Optional.
	Scope myScope;
	EnumDeclaration[] members; ///< At least one.
	/**
	 * With an anonymous enum, the base type (specified with a colon)
	 * is the type of using that enum declaration. With a named enum the
	 * type of the enum declaration is Enum, and the base type determines
	 * what the declarations can be initialised with.
	 */
	Type base;

	bool resolved;

public:
	this() { super(NodeType.Enum); }
}

/**
 * Compile time assert.
 * If the expression is false, then compilation is halted with
 * an optional message.
 *
 * @ingroup irNode irTopLevel
 */
class StaticAssert : Node
{
public:
	Exp exp;  ///< Often just false.
	Exp message;  ///< Optional.


public:
	this() { super(NodeType.StaticAssert); }
}

/**
 * Unittest code to be run on if selected by user.
 *
 * @ingroup irNode irTopLevel
 */
class Unittest : Node
{
public:
	BlockStatement _body; ///< Contains statements.


public:
	this() { super(NodeType.Unittest); }
}

/**
 * Node represention a compile time conditional compilation.
 *
 * Several types Condition is collapsed into this class, including
 * version, debug and static if. Used together with ConditionStatement
 * and ConditionTopLevel.
 *
 * @ingroup irNode irTopLevel irStatement
 */
class Condition : Node
{
public:
	/**
	 * Used to specify the exact sort of condition.
	 */
	enum Kind
	{
		/// version(identifier) {}
		Version,
		/// debug {}, debug (identifier) {}
		Debug,
		/// static if (exp) {}
		StaticIf,
	}


public:
	/// What kind of Condition is this?
	Kind kind;
	Exp exp;


public:
	this() { super(NodeType.Condition); }
}

/**
 * Node represention a compile time conditional compilation, at the
 * toplevel. Uses Condition to specify the if it should be compiled.
 *
 * @ingroup irNode irTopLevel
 */
class ConditionTopLevel : Node
{
public:
	/// Specifier.
	Condition condition;

	/// If a else is following.
	bool elsePresent;

	/// version(foo) { @<members> }
	TopLevelBlock members;
	/// version(foo) { @<members> } else { @<_else> }
	TopLevelBlock _else;


public:
	this() { super(NodeType.ConditionTopLevel); }
}

/**
 * Is a ";". short and simple.
 *
 * @ingroup irNode irTopLevel
 */
class EmptyTopLevel : Node
{
public:
	this() { super(NodeType.EmptyTopLevel); }
}

/**
 * Node represention of a function mixin.
 *
 * @ingroup irNode irTopLevel
 */
class MixinFunction : Node
{
public:
	string name; //< Not optional.

	/**
	 * Contains statements. These nodes are raw nodes and are
	 * processed in any form and as such should not be visited.
	 * They are copied and processed when the mixin is instanciated.
	 */
	BlockStatement raw;

public:
	this() { super(NodeType.MixinFunction); }
}

/**
 * Node represention of a template mixin.
 *
 * @ingroup irNode irTopLevel
 */
class MixinTemplate : Node
{
public:
	string name; //< Not optional.

	/**
	 * Toplevel nodes. These nodes are raw nodes and are not
	 * processed in any form and as such should not be visited.
	 * They are copied and processed when the mixin is instanciated.
	 */
	TopLevelBlock raw;

public:
	this() { super(NodeType.MixinTemplate); }
}

/**
 * The building block of user defined attributes.
 *
 * Defined fairly simply:
 * ---
 * @interface Name {
 *     int someVar;
 *     string someOtherVar;
 *     bool somethingWithADefault = true;
 * }
 * ---
 *
 * Only variables can be present. Any assign (or when initializing them
 * normally, in fact) must be known at compile time.
 *
 * @p UserAttributes are mangled as 'T' + name.
 *
 * @ingroup irNode irTopLevel
 */
class UserAttribute : Type
{
public:
	string name;
	Variable[] fields;
	Scope myScope;
	Class layoutClass;

	bool isResolved;
	bool isActualized;

public:
	this() { super(NodeType.UserAttribute); }
}
