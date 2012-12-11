// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.context;

import std.string : format;

import volt.exceptions;
import volt.ir.base;
import volt.ir.toplevel;
import volt.ir.declaration;


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
		Value,
		Type,
		Scope,
		Function,
	}


public:
	/// Exported name.
	string name;
	/// Parent node, never null.
	Scope parent;

	/// Type contained within store.
	Kind kind;

	/// This context, node might point to owning node.
	Scope s;
	/// Owning node, for Value and Type .
	Node node;
	/// Overloaded functions.
	Function[] functions;


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
	 * Used for functions. Not really intended for general
	 * consumption but are instead called from the addFunction
	 * member in Scope.
	 */
	this(Scope s, Function fn)
	{
		this.parent = s;
		this.functions = [fn];
		this.kind = Kind.Function;
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
	/// Name of this scope, needed for toplevel modules.
	string name;

	/// Owning node.
	Node node;
	/// Parent scope, if null toplevel module.
	Scope parent;
	/// Declared symbols in this scope.
	Store[string] symbols;


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
	void addScope(Node n, Scope s, string name)
	in {
		assert(n !is null);
	}
	body {
		errorOn(n, name);

		auto store = new Store(this, n, name, Store.Kind.Scope);
		symbols[name] = store;
		store.s = s;
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
	void addType(Node n, string name)
	{
		errorOn(n, name);
		symbols[name] = new Store(this, n, name, Store.Kind.Type);
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
	void addValue(Node n, string name)
	{
		errorOn(n, name);
		symbols[name] = new Store(this, n, name, Store.Kind.Value);
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
	void addFunction(Function fn, string name)
	{
		auto ret = name in symbols;

		if (ret is null) {
			symbols[name] = new Store(this, fn);
			return;
		} else if (ret.kind == Store.Kind.Function) {
			ret.functions ~= fn;
			return;
		}
		errorDefined(fn, name);
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
	{
		errorOn(s.node, name);
		symbols[name] = s;
	}

	/**
	 * Doesn't look in parent scopes, just this Store.
	 *
	 * Returns: the Store found, or null on lookup failure.
	 *
	 * Side-effects:
	 *   None.
	 */
	Store getStore(string name)
	{
		auto ret = name in symbols;
		if (ret is null)
			return null;

		return *ret;
	}

	/**
	 * Return this scope with a copy of its symbol table.
	 * 
	 * That is to say, modifying the copy's symbol table
	 * won't alter the original's.
	 */
	Scope dup()
	{
		auto copy = this;
		auto oldSymbols = copy.symbols;
		copy.symbols = null;
		foreach (k, v; oldSymbols) {
			copy.symbols[k] = v;
		}
		return copy;
	}


private:
	void errorOn(Node n, string name)
	{
		auto ret = name in symbols;
		if (ret is null)
			return;

		errorDefined(n, name);
	}

	void errorDefined(Node n, string name)
	{
		auto str = format("\"%s\" already defined", name);
		throw new CompilerPanic(n.location, str);
	}
}
