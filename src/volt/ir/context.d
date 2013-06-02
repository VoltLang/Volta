// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.context;

import std.string : format;

import volt.errors;
import volt.ir.base;
import volt.ir.type;
import volt.ir.toplevel;
import volt.ir.declaration;
import volt.ir.expression;


/**
 * @defgroup irContext IR Context Classes
 *
 * These non-nodes handles the symbol space of nodes.
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

/**
 * A container class for a various things that can be stored
 * in a Scope.
 * 
 * If kind is Value, node is a Variable. If it's Type, the
 * node is a Type. Scope means s is a named scope, and node
 * contains the node that introduced the scope. Functions
 * means that functions contain an overload set of a function.
 *
 * Note: not a node.
 *
 * @ingroup irNode irContext
 */
final class Store
{
public:
	/**
	 * Class specifier.
	 */
	enum Kind
	{
		Alias,
		Value,
		Type,
		Scope,
		Function,
		Template,
		EnumDeclaration,
		FunctionParam,
	}


public:
	/// Exported name.
	string name;
	/// Parent node, never null.
	Scope parent;

	/// Type contained within store.
	Kind kind;



	/**
	 * Owning node, for all types.
	 * For function the first encountered one.
	 */
	Node node;

	/**
	 * For Scope this context, node might point to owning node.
	 * For Alias the scope into which the alias should be resolved from.
	 */
	Scope s;

	/**
	 * Overloaded functions.
	 */
	Function[] functions;

	/**
	 * Store pointed to by alias.
	 */
	Store myAlias;


public:
	/**
	 * Used for Value, Type and Scope stores. Not really intended
	 * for general consumption but are instead called from the
	 * add members in Scope.
	 */
	this(Scope s, Node n, string name, Kind kind)
	in {
		assert(kind != Kind.Function);
	}
	body {
		this.name = name;
		this.node = n;
		this.kind = kind;
		this.parent = s;
	}

	/**
	 * Used for Aliases Not really intended for general consumption
	 * but are instead called from the addAlias function on Scope.
	 */
	this(Scope parent, Node n, string name, Scope look, Kind kind)
	in {
		assert(kind == Kind.Alias);
	}
	body {
		this.name = name;
		this.node = n;
		this.kind = kind;
		this.parent = parent;
		if (look is null) {
			this.s = parent;
		} else {
			this.s = look;
		}
	}

	/**
	 * Used for functions. Not really intended for general
	 * consumption but are instead called from the addFunction
	 * member in Scope.
	 */
	this(Scope s, Function fn, string name)
	{
		this.name = name;
		this.node = fn;
		this.parent = s;
		this.functions = [fn];
		this.kind = Kind.Function;
	}

	/**
	 * Used for enums.
	 * The name will usually be the name of the enum declaration.
	 * Not really intended for general consumption, but called from the
	 * addEnumDeclaration member in Scope.
	 */
	this(Scope parent, EnumDeclaration ed, string name)
	{
		this.parent = parent;
		this.node = ed;
		this.kind = Kind.EnumDeclaration;
	}

	void markAliasResolved(Store s)
	{
		assert(kind == Kind.Alias);
		assert(myAlias is null);
		myAlias = s;
	}

	void markAliasResolved(Type t)
	{
		assert(kind == Kind.Alias);
		assert(myAlias is null);
		kind = Kind.Type;
		node = t;
	}
}

/**
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
	/// "Anonymous" identifier uniquifier value.
	uint anon;

	/// Name of this scope, needed for toplevel modules.
	string name;

	/// Owning node.
	Node node;
	/// Parent scope, if null toplevel module.
	Scope parent;
	/// Declared symbols in this scope.
	Store[string] symbols;

	/**
	 * Modules to implicitly look up symbols in.
	 *
	 * Currently only populated on module scopes.
	 */
	Module[] importedModules;
	Access[] importedAccess;

	int nestedDepth;

public:
	/**
	 * For toplevel modules.
	 *
	 * Side-effects:
	 *   None.
	 */
	this(Module m, string name)
	{
		this.name = name;
		this.node = m;
	}

	/**
	 * For named imports, classes, structs and unions.
	 *
	 * Side-effects:
	 *   None.
	 */
	this(Scope parent, Node node, string name)
	{
		this.name = name;
		this.node = node;
		this.parent = parent;
	}

	void remove(string name)
	{
		symbols.remove(name);
	}

	string genAnonIdent()
	{
		return "__anon" ~ to!string(anon++);
	}

	/**
	 * Add a unresolved Alias to this scope. The scope in which the
	 * alias is resolved to is default this scope, can be changed
	 * with the look argument, used by import rebinds.
	 *
	 * Throws:
	 *   CompilerPanic if another symbol of same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addAlias(Alias n, string name, Scope look = null)
	in {
		assert(n !is null);
		assert(name !is null);
	}
	body {
		errorOn(n, name);
		auto store = new Store(this, n, name, look, Store.Kind.Alias);
		symbols[name] = store;
		return store;
	}

	/**
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
		store.s = s;
		return store;
	}

	/**
	 * Add a user defined type.
	 *
	 * Throws:
	 *   CompilerPanic if another symbol of same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addType(Node n, string name)
	in {
		assert(n !is null);
		assert(name !is null);
	}
	body {
		errorOn(n, name);
		auto store = new Store(this, n, name, Store.Kind.Type);
		symbols[name] = store;
		return store;
	}

	/**
	 * Add a value like a constant or a function variable.
	 *
	 * Throws:
	 *   CompilerPanic if another symbol of same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addValue(Node n, string name)
	in {
		assert(n !is null);
		assert(name !is null);
	}
	body {
		errorOn(n, name);
		ir.Store store;
		if (n.nodeType == ir.NodeType.FunctionParam) {
			store = new Store(this, n, name, Store.Kind.FunctionParam);
		} else {
			store = new Store(this, n, name, Store.Kind.Value);
		}
		symbols[name] = store;
		return store;
	}

	/**
	 * Add a function to this scope, will append function if one of
	 * declared function of the same name is found.
	 *
	 * Throws:
	 *   CompilerPanic if a non-function of the same name is found.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store addFunction(Function fn, string name)
	in {
		assert(fn !is null);
		assert(name !is null);
	}
	body {
		auto ret = name in symbols;

		if (ret is null) {
			auto store = new Store(this, fn, name);
			symbols[name] = store;
			return store;
		} else if (ret.kind == Store.Kind.Function) {
			ret.functions ~= fn;
			return *ret;
		}
		errorDefined(fn, name);
		assert(false);
	}

	/**
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

	/**
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

	/**
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

	/**
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
		if (ret is null)
			return null;
		auto s = *ret;
		while (s.myAlias !is null) {
			s = s.myAlias;
		}
		return s;
	}

	/**
	 * Get all Variables in the Scope the have Nested storage.
	 */
	Declaration[] getNestedDeclarations()
	{
		Declaration[] variables;
		foreach (store; symbols.values) {
			auto variable = cast(ir.Variable) store.node;
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
		assert(n !is null);
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
		throw panic(n.location, str);
	}
}
