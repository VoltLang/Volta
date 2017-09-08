// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.context;

import watt.conv : toString;
import watt.text.format : format;

import volt.errors;
import volt.ir.base;
import volt.ir.type;
import volt.ir.toplevel;
import volt.ir.declaration;
import volt.ir.expression;
import volt.token.location;


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
		Alias,
		Merge,
		Function,
		Template,
		Reserved,
		FunctionParam,
		EnumDeclaration,
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
	Node originalNode;

	/*!
	 * The scope for this context, node might point to owning node,
	 * the exception being Scope, which does not have a owning node.
	 */
	Scope myScope;

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
		this.parent = parent;
		this.node = ed;
		this.kind = Kind.EnumDeclaration;
	}

	/*!
	 * Construct an invalid Store.
	 * Used for copying Stores for CTFE, do not use for anything else.
	 */
	this()
	{
	}

	void markAliasResolved(Store s)
	{
		assert(kind == Kind.Alias);
		assert(myAlias is null);
		myAlias = s;
		s.originalNode = node;
	}

	void markAliasResolved(Type t)
	{
		assert(kind == Kind.Alias);
		assert(myAlias is null);
		kind = Kind.Type;
		originalNode = node;
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
	 */
	Store reserveId(Node n, string name)
	{
		auto store = new Store(this, n, name, Store.Kind.Reserved);
		auto ret = name in symbols;
		if (ret is null) {
			symbols[name] = store;
			return store;
		}
		throw panic(n, "failed to reserve ident '%s'", name);
	}

	/*!
	 * Add an unresolved Alias to this scope. The scope that the
	 * alias is resolved to is defaulted to this scope, but this can be
	 * changed with the look argument, used by import rebinds.
	 *
	 * Throws:
	 *   CompilerPanic if another symbol of same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addAlias(Alias n, string name)
	in {
		assert(n !is null);
		assert(name !is null);
	}
	body {

		auto store = new Store(this, n, name, Store.Kind.Alias);

		auto ret = name in symbols;
		if (ret is null) {
			symbols[name] = store;
			return store;
		}
		auto merge = *ret;

		if (merge.kind == Store.Kind.Alias) {
			assert(merge.originalNode is null);
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
			errorDefined(n, name);
		}

		merge.aliases ~= n;
		return store;
	}

	/*!
	 * Add a named scope, @n is the node which introduced
	 * this scope, must not be null.
	 *
	 * Throws:
	 *   CompilerPanic if another symbol of same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addScope(Node n, Scope s, string name)
	in {
		assert(n !is null);
		assert(name !is null);
	}
	body {
		errorOn(n, name);

		auto store = new Store(this, n, name, Store.Kind.Scope);
		symbols[name] = store;
		store.myScope = s;
		store.importBindAccess = Access.Private;
		return store;
	}

	/*!
	 * Add a user defined type.
	 *
	 * Throws:
	 *   CompilerPanic if another symbol of same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addType(Node n, string name)
	{
		if (n is null) {
			throw panic("null Node provided to addType");
		}
		if (name is null) {
			throw panic(n.loc, "null name provided to addType");
		}
		errorOn(n, name);
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
	 * Throws:
	 *   CompilerPanic if another symbol of same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addValue(Node n, string name)
	{
		if (n is null) {
			throw panic("null node passed to addValue");
		}
		if (name is null) {
			throw panic(n.loc, "null name passed to addValue");
		}
		errorOn(n, name);
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
	Store addFunction(Function func, string name)
	in {
		assert(func !is null);
		assert(name !is null);
	}
	body {
		auto ret = name in symbols;

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

		errorDefined(func, name);
		assert(false);
	}

	/*!
	 * Add a user defined template.
	 *
	 * Throws:
	 *   CompilerPanic if another symbol of same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addTemplate(Node n, string name)
	in {
		assert(n !is null);
		assert(name !is null);
	}
	body {
		errorOn(n, name);
		auto store = new Store(this, n, name, Store.Kind.Template);
		symbols[name] = store;
		return store;
	}

	/*!
	 * Add a named expression to the scope.
	 *
	 * Throws:
	 *   CompilerPanic if another symbol of the same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addEnumDeclaration(EnumDeclaration e)
	in {
		assert(e !is null);
		assert(e.name.length > 0);
	}
	body {
		errorOn(e, e.name);
		auto store = new Store(this, e, e.name);
		symbols[e.name] = store;
		return store;
	}

	/*!
	 * Add a pre-existing store to the scope.
	 *
	 * Throws:
	 *   CompilerPanic if another symbol of the same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	void addStore(Store s, string name)
	in {
		assert(s !is null);
		assert(s.node !is null);
		assert(name !is null);
	}
	body {
		errorOn(s.node, name);
		symbols[name] = s;
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
	void errorOn(Node n, string name)
	in {
		assert(name !is null);
	}
	body {
		auto ret = name in symbols;
		if (ret is null)
			return;

		errorDefined(n, name);
	}

	void errorDefined(Node n, string name)
	{
		auto str = format("\"%s\" already defined", name);
		throw panic(n.loc, str);
	}
}
