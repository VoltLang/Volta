/*#D*/
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.ir.context;

import watt.conv : toString;
import watt.text.format : format;

import volta.ir.base;
import volta.ir.type;
import volta.ir.toplevel;
import volta.ir.declaration;
import volta.ir.expression;
import volta.ir.location;
import volta.ir.templates;

enum Status
{
	Success,
	Error
}

/*!
 * @defgroup irContext IR Context Classes
 *
 * These non-nodes handle the symbol space of nodes.
 * These provide 'mechanism' over 'policy'; how look
 * ups are performed, where they're performed. Parameter
 * shadowing parent Scopes is allowed by these, that
 * error has to come from another layer. The main
 * restriction provided by these classes is that you can't
 * have multiple Stores associated with the same name in
 * a single Scope.
 * 
 * Some passes that deal with context are the Context pass,
 * the DeclGatherer pass, and the ScopeManager pass.
 *
 * In addition most of the semantic passes will lookup
 * things in Scopes.
 *
 * @ingroup irNode
 */

/*!
 * A container class for a various things that can be stored
 * in a Scope.
 * 
 * If kind is Value, node is a Variable. If it's Type, the
 * node is a Type. Scope means s is a named scope, and node
 * contains the node that introduced the scope. Functions
 * means that functions contain an overload set of a function.
 * An Expression Store contains a delegate that generates a new
 * expression in place of the lookup.
 *
 * Note: not a node.
 *
 * @ingroup irNode irContext
 */
final class Store
{
public:
	/*!
	 * Class specifier.
	 */
	enum Kind
	{
		Type,
		Value,
		Scope,
		MultiScope,
		Alias,
		Merge,
		Function,
		Template,
		Reserved,
		FunctionParam,
		EnumDeclaration,
		TemplateInstance,
	}


public:
	//! Exported name.
	string name;
	//! Parent node, never null.
	Scope parent;

	//! Type contained within store.
	Kind kind;

	/*!
	 * Owning node, for all types.
	 * For function the first encountered one.
	 */
	Node node;

	/*!
	 * If node was modified (e.g. alias) this is what it was first.
	 */
	Node[] originalNodes;

	/*!
	 * The scope for this context, node might point to owning node,
	 * the exception being Scope, which does not have a owning node.
	 */
	Scope myScope;

	/*!
	 * The scope set for a MultiScope store.
	 */
	Scope[] scopes;

	/*!
	 * Overloaded functions.
	 */
	Function[] functions;

	/*!
	 * Merging of aliases and functions, used if Kind is Merge.
	 */
	Alias[] aliases;

	/*!
	 * Store pointed to by alias.
	 */
	Store myAlias;

	//! Public except for binds from private imports.
	Access importBindAccess = Access.Public;

	//! Was this symbol introduced by import <> : thisSymbol? Used for protection.
	bool importAlias;

	//! Can the user overwrite this? Used for pieces of import chains, so you can rebind a module as 'core', for example.
	bool fromImplicitContextChain;

	//! Retrieve the unique id of this node.
	final @property size_t uniqueId() { return mUniqueId; }


private:
	NodeID mUniqueId;
	static NodeID mUniqueIdCounter; // We are single threaded.


public:
	/*!
	 * Used for Alias, Value, Type and Scope stores.
	 * Not really intended for general consumption but
	 * are instead called from the add members in Scope.
	 */
	this(Scope s, Node n, string name, Kind kind)
	in {
		assert(kind != Kind.Function);
		assert(n !is null);
	}
	body {
		this();
		this.name = name;
		this.node = n;
		this.kind = kind;
		this.parent = s;
	}

	/*!
	 * Used for functions. Not really intended for general
	 * consumption but are instead called from the addFunction
	 * member in Scope.
	 */
	this(Scope s, Function func, string name)
	in {
		assert(func !is null);
	}
	body {
		this();
		this.name = name;
		this.node = func;
		this.parent = s;
		this.functions = [func];
		this.kind = Kind.Function;
	}

	/*!
	 * As above but for multiple functions at once.
	 * Internal use only.
	 */
	this(Scope s, Function[] func, string name)
	{
		this();
		this.name = name;
		this.node = func[0];
		this.parent = s;
		this.functions = func;
		this.kind = Kind.Function;
	}

	/*!
	 * Used for enums.
	 * The name will usually be the name of the enum declaration.
	 * Not really intended for general consumption, but called from the
	 * addEnumDeclaration member in Scope.
	 */
	this(Scope parent, EnumDeclaration ed, string name)
	in {
		assert(ed !is null);
	}
	body {
		this();
		this.parent = parent;
		this.node = ed;
		this.kind = Kind.EnumDeclaration;
	}

	this(Scope parent, TemplateInstance ti)
	{
		this();
		this.parent = parent;
		this.node = ti;
		this.kind = Kind.TemplateInstance;
		this.name = ti.instanceName;
	}

	/*!
	 * Construct an invalid Store.
	 * Used for copying Stores for CTFE, do not use for anything else.
	 */
	this()
	{
		this.mUniqueId = mUniqueIdCounter++;
	}

	void markAliasResolved(Store s)
	{
		assert(kind == Kind.Alias);
		assert(myAlias is null);
		myAlias = s;
		s.originalNodes ~= node;
	}

	void markAliasResolved(Type t)
	{
		assert(kind == Kind.Alias);
		assert(myAlias is null);
		kind = Kind.Type;
		originalNodes ~= node;
		node = t;
	}
}

/*!
 * A single scope containing declared items and their identifiers.
 * 
 * See store for what can be held in a scope. These things are
 * associated with a string. Scopes have parent Scopes, but these
 * don't affect getStores lookup -- write a look up function for
 * your specific needs.
 *
 * Structs, Classes, Interfaces, Functions, and Modules all have scopes. 
 *
 * Note: not a node.
 *
 * @ingroup irNode irContext
 */
final class Scope
{
public:
	//! "Anonymous" identifier uniquifier value.
	uint anon;

	//! Name of this scope, needed for toplevel modules.
	string name;

	//! Owning node.
	Node node;
	//! Parent scope, if null toplevel module.
	Scope parent;
	//! Declared symbols in this scope.
	Store[string] symbols;
	//! This scope represents multiple scopes. Only used for multibind imports.
	Scope[] multibindScopes;

	/*!
	 * Modules to implicitly look up symbols in.
	 *
	 * Currently only populated on module scopes.
	 */
	Module[] importedModules;
	Access[] importedAccess;

	int nestedDepth;

public:
	/*!
	 * For toplevel modules.
	 *
	 * Side-effects:
	 *   None.
	 */
	this(Module m, string name)
	{
		this.name = name;
		this.node = m;
		assert(this.node !is null);
	}

	/*!
	 * For named imports, classes, structs and unions.
	 *
	 * Side-effects:
	 *   None.
	 */
	this(Scope parent, Node node, string name, int nestedDepth)
	{
		this.name = name;
		this.node = node;
		this.parent = parent;
		this.nestedDepth = nestedDepth;
		assert(this.node !is null);
	}

	/*!
	 * Create a scope that represents multiple scopes.
	 *
	 * Used in multibind imports, by the lookup code.
	 */
	this(Scope[] scopes)
	{
		multibindScopes = scopes;
	}

	/*!
	 * Create an invalid Scope. Internal use only.
	 */
	this()
	{
	}

	void remove(string name)
	{
		symbols.remove(name);
	}

	string genAnonIdent()
	{
		return format("__anon%s", .toString(anon++));
	}

	/*!
	 * Reserve a identifier in this scope.
	 *
	 * Returns: null, if an identifier couldn't be reserved.
	 */
	Store reserveId(Node n, string name)
	{
		auto store = new Store(this, n, name, Store.Kind.Reserved);
		auto ret = name in symbols;
		if (ret is null) {
			symbols[name] = store;
			return store;
		}
		return null;
	}

	/*!
	 * Add an unresolved Alias to this scope. The scope that the
	 * alias is resolved to is defaulted to this scope, but this can be
	 * changed with the look argument, used by import rebinds.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addAlias(Alias n, string name, out Status status)
	in {
		assert(n !is null);
		assert(name !is null);
	}
	body {
		status = Status.Success;
		auto store = new Store(this, n, name, Store.Kind.Alias);

		auto ret = name in symbols;
		if (ret is null) {
			symbols[name] = store;
			return store;
		}
		auto merge = *ret;

		if (merge.kind == Store.Kind.Alias) {
			assert(merge.originalNodes is null);
			auto old = cast(Alias)merge.node;
			assert(old !is null);

			// Pretend that the first alias has
			// always been a merge store.
			merge = new Store(this, old, name, Store.Kind.Merge);
			merge.aliases ~= old;
			symbols[name] = merge;
		} else if (merge.kind == Store.Kind.Function) {
			merge.kind = Store.Kind.Merge;
		} else if (merge.kind != Store.Kind.Merge) {
			status = Status.Error;
		}

		merge.aliases ~= n;
		return store;
	}

	/*!
	 * Add a named scope, @n is the node which introduced
	 * this scope, must not be null.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addScope(Node n, Scope s, string name, out Status status)
	in {
		assert(n !is null);
		assert(name !is null);
	}
	body {
		errorOn(n, name, /*#out*/status);

		auto store = new Store(this, n, name, Store.Kind.Scope);
		symbols[name] = store;
		store.myScope = s;
		store.importBindAccess = Access.Private;
		return store;
	}

	/*!
	 * Add a named multiscope, `n` is the node which introduced
	 * this scope and must not be null.
	 */
	Store addMultiScope(Node n, Scope[] s, string name, out Status status)
	in {
		assert(n !is null);
		assert(name !is null);
	} body {
		errorOn(n, name, /*#out*/status);

		auto store = new Store(this, n, name, Store.Kind.MultiScope);
		symbols[name] = store;
		store.scopes = s;
		store.importBindAccess = Access.Private;
		return store;
	}

	/*!
	 * Add a user defined type.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addType(Node n, string name, out Status status)
	{
		if (n is null || name is null) {
			status = Status.Error;
			return null;
		}
		errorOn(n, name, /*#out*/status);
		auto store = new Store(this, n, name, Store.Kind.Type);
		symbols[name] = store;

		auto named = cast(Named) n;
		if (named !is null) {
			assert(named.myScope !is null);
			store.myScope = named.myScope;
		}

		return store;
	}

	/*!
	 * Add a value like a constant or a function variable.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addValue(Node n, string name, out Status status)
	{
		if (n is null || name is null) {
			status = Status.Error;
		}
		errorOn(n, name, /*#out*/status);
		Store store;
		if (n.nodeType == NodeType.FunctionParam) {
			store = new Store(this, n, name, Store.Kind.FunctionParam);
		} else {
			store = new Store(this, n, name, Store.Kind.Value);
		}
		symbols[name] = store;
		return store;
	}

	/*!
	 * Add a function to this scope, will append function if one of
	 * declared function of the same name is found.
	 *
	 * Throws:
	 *   CompilerPanic if a non-function of the same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addFunction(Function func, string name, out Status status)
	in {
		assert(func !is null);
		assert(name !is null);
	}
	body {
		auto ret = name in symbols;
		status = Status.Success;

		if (ret is null) {
			auto store = new Store(this, func, name);
			symbols[name] = store;
			return store;
		}

		auto merge = *ret;
		if (ret.kind == Store.Kind.Function ||
		    ret.kind == Store.Kind.Merge) {
			merge.functions ~= func;
			return merge;
		}

		if (merge.kind == Store.Kind.Alias) {
			auto store = new Store(this, func, name);
			store.kind = Store.Kind.Merge;
			symbols[name] = store;

			auto a = cast(Alias) merge.node;
			assert(a !is null);
			store.aliases ~= a;
			return store;
		}

		status = Status.Error;
		return null;
	}

	/*!
	 * Add a user defined template.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addTemplate(Node n, string name, out Status status)
	in {
		assert(n !is null);
		assert(name !is null);
	}
	body {
		errorOn(n, name, /*#out*/status);
		auto store = new Store(this, n, name, Store.Kind.Template);
		symbols[name] = store;
		return store;
	}

	/*!
	 * Add a template instance to the scope.
	 */
	Store addTemplateInstance(TemplateInstance ti, out Status status)
	{
		errorOn(ti, ti.instanceName, /*#out*/status);
		auto store = new Store(this, ti);
		symbols[ti.instanceName] = store;
		return store;
	}

	/*!
	 * Add a named expression to the scope.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addEnumDeclaration(EnumDeclaration e, out Status status)
	in {
		assert(e !is null);
		assert(e.name.length > 0);
	}
	body {
		errorOn(e, e.name, /*#out*/status);
		auto store = new Store(this, e, e.name);
		symbols[e.name] = store;
		return store;
	}

	/*!
	 * Doesn't look in parent scopes, just this Store.
	 *
	 * Returns: the Store found, store pointed to by alias,
	 * or null on lookup failure.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store getStore(string name)
	{
		auto ret = name in symbols;
		if (ret is null) {
			return null;
		}
		return *ret;
	}

	/*!
	 * Get all Variables in the Scope the have Nested storage.
	 */
	Declaration[] getNestedDeclarations()
	{
		Declaration[] variables;
		foreach (store; symbols.values) {
			auto variable = cast(Variable) store.node;
			if (variable is null || variable.storage != Variable.Storage.Nested) {
				continue;
			}
			variables ~= variable;
		}
		return variables;
	}

private:
	void errorOn(Node n, string name, out Status status)
	in {
		assert(name !is null);
	}
	body {
		auto ret = name in symbols;
		if (ret is null) {
			status = Status.Success;
		} else {
			status = Status.Error;
		}
	}
}
