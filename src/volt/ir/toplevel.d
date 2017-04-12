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
import volt.ir.templates;

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
	bool isAnonymous;  ///< Auto generated module name, unimportable.

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

	Struct moduleInfo;
	Variable moduleInfoRoot;

private:
	size_t mId;

public:
	this() { super(NodeType.Module); }

	this(Module old)
	{
		super(NodeType.Module, old);
		this.name = old.name;
		this.children = old.children;
		this.myScope = old.myScope;
		this.hasPhase1 = old.hasPhase1;
		this.gathered = old.gathered;
		this.mId = old.mId;
		this.isAnonymous = old.isAnonymous;
		this.moduleInfo = old.moduleInfo;
		this.moduleInfoRoot = old.moduleInfoRoot;
	}

	/// Get a unique number for this module.
	size_t getId()
	{
		auto id = mId;
		mId++;
		return id;
	}
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

	this(TopLevelBlock old)
	{
		super(NodeType.TopLevelBlock, old);
		version (Volt) {
			this.nodes = new old.nodes[0 .. $];
		} else {
			this.nodes = old.nodes.dup;
		}
	}
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
	Identifier[][] aliases;

	/// This points at the imported module -- filled in by ImportResolver.
	Module targetModule;


public:
	this() { super(NodeType.Import); }

	this(Import old)
	{
		super(NodeType.Import, old);
		this.access = old.access;
		this.isStatic = old.isStatic;
		this.name = old.name;
		this.bind = old.bind;
		version (Volt) {
			this.aliases = new old.aliases[0 .. $];
			foreach (i; 0 .. this.aliases.length) {
				auto oa = old.aliases[i];
				this.aliases[i] = new oa[0 .. $];
			}
		} else {
			this.aliases = old.aliases.dup;
			foreach (i; 0 .. this.aliases.length) {
				this.aliases[i] = old.aliases[i].dup;
			}
		}
		this.targetModule = old.targetModule;
	}
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
		Invalid,
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
		MangledName,
		Label,
	}


public:
	/// What kind of attribute.
	Kind kind;

	TopLevelBlock members;

	Attribute chain; ///< for "public abstract:"

	Exp[] arguments;  ///< If kind == Annotation or MangledName.

	/// Only if type == Align.
	int alignAmount;

public:
	this() { super(NodeType.Attribute); }

	this(Attribute old)
	{
		super(NodeType.Attribute, old);
		this.kind = old.kind;

		this.members = old.members;

		this.chain = old.chain;

		version (Volt) {
			this.arguments = new old.arguments[0 .. $];
		} else {
			this.arguments = old.arguments.dup;
		}

		this.alignAmount = old.alignAmount;
	}
}

/**
 * Named is a base class for named types, like Enum, Struct, Class and so on.
 * This is slightly different from Aggregate since Enum is not a Aggregate,
 * but is a named type.
 *
 * @ingroup irNode irTopLevel irType irDecl
 */
abstract class Named : Type
{
public:
	bool isResolved;

	/// Usability from other modules.
	Access access = Access.Public;

	string name; ///< Unmangled name of the NamedType.

	Scope myScope; ///< Context for this NamedType.

	Variable typeInfo;  ///< Filled in by the semantic pass.

public:
	this(NodeType nt) { super(nt); }

	this(NodeType nt, Named old)
	{
		super(nt, old);
		this.isResolved = old.isResolved;
		this.access = old.access;
		this.name = old.name;
		this.myScope = old.myScope;
		this.typeInfo = old.typeInfo;
	}
}

/**
 * Aggregate is a base class for Struct, Union & Class.
 *
 * @ingroup irNode irTopLevel irType irDecl
 */
abstract class Aggregate : Named
{
public:
	Aggregate[] anonymousAggregates;
	Variable[] anonymousVars;

	TopLevelBlock members; ///< Toplevel nodes.

	bool isActualized;

public:
	this(NodeType nt) { super(nt); }

	this(NodeType nt, Aggregate old)
	{
		super(nt, old);
		this.anonymousAggregates = old.anonymousAggregates;
		this.anonymousVars = old.anonymousVars;

		this.members = old.members;

		this.isActualized = old.isActualized;
	}
}

/**
 * Plain Old Data aggregates.
 * Struct and Union, basically.
 */
class PODAggregate : Aggregate
{
public:
	Function[] constructors;

public:
	this(NodeType nt) { super(nt); }

	this(NodeType nt, PODAggregate old)
	{
		super(nt, old);
	}
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
	Variable[] ifaceVariables;
	Variable initVariable;
	Class parentClass;  ///< Filled in by the typeverifier.
	_Interface[] parentInterfaces;  ///< Filled in by the typeverifier.
	size_t[] interfaceOffsets;  ///< Filled in by the typeverifier.
	Function[][] methodsCache;  ///< Filled in by the classresolver.

	/// How a lowered class will look internally.
	Struct layoutStruct;

	/// Is this the one true 'Object' to rule them all?
	bool isObject;

	bool isAbstract;

	bool isFinal;

	TemplateInstance templateInstance;  //< Optional. Non-null if this is a template instantiation.

public:
	this() { super(NodeType.Class); }

	this(Class old)
	{
		super(NodeType.Class, old);
		this.parent = old.parent;
		version (Volt) {
			this.interfaces = new old.interfaces[0 .. $];
			this.userConstructors = new old.userConstructors[0 .. $];
			this.methodsCache = new old.methodsCache[0 .. $];
		} else {
			this.interfaces = old.interfaces.dup;
			this.userConstructors = old.userConstructors.dup;
			this.methodsCache = old.methodsCache.dup;
		}

		this.vtableStruct = old.vtableStruct;
		this.vtableVariable = old.vtableVariable;
		version (Volt) {
			this.ifaceVariables = new old.ifaceVariables[0 .. $];
		} else {
			this.ifaceVariables = old.ifaceVariables.dup;
		}
		this.initVariable = old.initVariable;
		this.parentClass = old.parentClass;
		version (Volt) {
			this.parentInterfaces = new old.parentInterfaces[0 .. $];
			this.interfaceOffsets = new old.interfaceOffsets[0 .. $];
		} else  {
			this.parentInterfaces = old.parentInterfaces.dup;
			this.interfaceOffsets = old.interfaceOffsets.dup;
		}

		this.layoutStruct = old.layoutStruct;

		this.isObject = old.isObject;
		this.isAbstract = old.isAbstract;
		this.isFinal = old.isFinal;
		this.templateInstance = old.templateInstance;
	}
}

/**
 * Java style interface declaration. 
 * An interface defines multiple functions that an implementing
 * class must define. A class can inherit from multiple interfaces,
 * and can be treated as an instance of any one of them. 
 *
 * @ingroup irNode irTopLevel irType irDecl
 */
class _Interface : Aggregate
{
public:
	QualifiedName[] interfaces; ///< Super interfaces to this.
	_Interface[] parentInterfaces;  ///< Filled in by the typeverifier.

	/// How a lowered interface will look internally.
	Struct layoutStruct;

	TemplateInstance templateInstance;  //< Optional. Non-null if this is a template instantiation.

public:
	this() { super(NodeType.Interface); }

	this(_Interface old)
	{
		super(NodeType.Interface, old);
		version (Volt) {
			this.interfaces = new old.interfaces[0 .. $];
			this.parentInterfaces = new old.parentInterfaces[0 .. $];
		} else {
			this.interfaces = old.interfaces.dup;
			this.parentInterfaces = old.parentInterfaces.dup;
		}

		this.layoutStruct = old.layoutStruct;
		this.templateInstance = old.templateInstance;
	}
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
class Union : PODAggregate
{
public:
	size_t totalSize; // Total size in memory.

	TemplateInstance templateInstance;  //< Optional. Non-null if this is a template instantiation.

public:
	this() { super(NodeType.Union); }

	this(Union old)
	{
		super(NodeType.Union, old);
		this.totalSize = old.totalSize;
		this.templateInstance = old.templateInstance;
	}
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
class Struct : PODAggregate
{
public:
	Node loweredNode;  ///< If not null, this struct was lowered from this.

	TemplateInstance templateInstance;  //< Optional. Non-null if this is a template instantiation.

public:
	this() { super(NodeType.Struct); }

	this(Struct old)
	{
		super(NodeType.Struct, old);
		this.loweredNode = old.loweredNode;
		this.templateInstance = old.templateInstance;
	}
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
class Enum : Named
{
public:
	EnumDeclaration[] members; ///< At least one.
	/**
	 * With an anonymous enum, the base type (specified with a colon)
	 * is the type of using that enum declaration. With a named enum the
	 * type of the enum declaration is Enum, and the base type determines
	 * what the declarations can be initialised with.
	 */
	Type base;

public:
	this() { super(NodeType.Enum); }

	this(Enum old)
	{
		super(NodeType.Enum, old);
		version (Volt) {
			this.members = new old.members[0 .. $];
		} else {
			this.members = old.members.dup;
		}
		this.base = old.base;
	}
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

	this(Unittest old)
	{
		super(NodeType.Unittest, old);
		this._body = old._body;
	}
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
		Invalid,
		/// version (identifier) {}
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

	this(Condition old)
	{
		super(NodeType.Condition, old);
		this.kind = old.kind;
		this.exp = old.exp;
	}
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

	/// version (foo) { @<members> }
	TopLevelBlock members;
	/// version (foo) { @<members> } else { @<_else> }
	TopLevelBlock _else;


public:
	this() { super(NodeType.ConditionTopLevel); }

	this(ConditionTopLevel old)
	{
		super(NodeType.ConditionTopLevel, old);
		this.condition = old.condition;

		this.elsePresent = old.elsePresent;

		this.members = old.members;
		this._else = old._else;
	}
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

	this(MixinFunction old)
	{
		super(NodeType.MixinFunction, old);
		this.name = old.name;
		this.raw = old.raw;
	}
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

	this(MixinTemplate old)
	{
		super(NodeType.MixinTemplate, old);
		this.name = old.name;
		this.raw = old.raw;
	}
}
