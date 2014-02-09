// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.lookup;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util : getScopeFromStore, getScopeFromType;
import volt.semantic.util : ensureResolved;

import volt.errors;
import volt.interfaces;
import volt.token.location;


/**
 * Look up an identifier in this scope only. 
 * Doesn't check parent scopes, parent classes, imports, or anywhere else but the
 * given scope.
 */
ir.Store lookupOnlyThisScope(LanguagePass lp, ir.Scope _scope, Location loc, string name)
{
	auto store = _scope.getStore(name);
	if (store !is null) {
		return ensureResolved(lp, store);
	}
	return null;
}

/**
 * Look up an identifier in this scope, in parent scopes (in
 * the case of classes), and in any imports for this scope.
 *
 * A usable scope for this function is retrieved from the
 * getFirstThisable function.
 *
 * @todo actually lookup imports.
 */
ir.Store lookupAsThisScope(LanguagePass lp, ir.Scope _scope, Location loc, string name)
{
	ir.Class _class;
	do {
		auto ret = lookupAsImportScope(lp, _scope, loc, name);
		if (ret !is null)
			return ensureResolved(lp, ret);
	} while (getClassParentsScope(lp, _scope, _scope, _class));

	return null;
}

/**
 * Lookup up as identifier in this scope, and any public imports.
 * Used for rebinding imports.
 * Returns the store or null if no match was found.
 */
ir.Store lookupAsImportScope(LanguagePass lp, ir.Scope _scope, Location loc, string name)
{
	auto store = lookupOnlyThisScope(lp, _scope, loc, name);
	if (store !is null) {
		return ensureResolved(lp, store);
	}

	foreach (i, submod; _scope.importedModules) {
		if (_scope.importedAccess[i] == ir.Access.Public) {
			store = submod.myScope.getStore(name);
			if (store !is null) {
				return ensureResolved(lp, store);
			}
		}
	}

	return null;
}

/**
 * Look up a QualifiedName chain, the first identifier is looked up globaly,
 * and the result is treated as a scope to lookup the next one should there be
 * more identifiers.
 */
ir.Store lookup(LanguagePass lp, ir.Scope _scope, ir.QualifiedName qn)
{
	auto last = cast(int)qn.identifiers.length - 1;
	auto current = qn.leadingDot ? getTopScope(_scope) : _scope;

	foreach (i, id; qn.identifiers) {
		ir.Store store;
		string name = id.value;
		Location loc = id.location;

		/**
		 * The first lookup should be done globally the following
		 * in only that context. Leading dot taken care of above.
		 */
		if (i == 0) {
			store = lookup(lp, current, loc, name);
			if (store is null) {
				return null;
			}
			auto asImport = cast(ir.Import) store.node;
			if (asImport !is null) {
				assert(asImport.targetModule !is null);
				current = asImport.targetModule.myScope;
			}
		} else {
			store = lookupAsImportScope(lp, current, loc, name);
		}

		if (store is null) {
			if (i == last) {
				return null;
			} else if (i == 0) {
				throw makeFailedLookup(loc, name);
			} else {
				throw makeNotMember(id, cast(ir.Type) current.node, name);
			}
		}

		// Need to resolve any aliases.
		store = ensureResolved(lp, store);

		if (i == last) {
			return store;
		} else {
			// Use improve error reporting by giving the scope.
			current = ensureScope(i == 0 ? null : current, loc, name, store);
		}
	}
	assert(false);
}

/**
 * Look up an identifier in a scope and its parent scopes.
 * Returns the store or null if no match was found.
 */
ir.Store lookup(LanguagePass lp, ir.Scope _scope, Location loc, string name)
{
	ir.Scope current = _scope, previous = _scope;
	while (current !is null) {
		auto store = lookupAsThisScope(lp, current, loc, name);
		if (store !is null) {
			return store;
		}

		previous = current;
		current = current.parent;
	}

	auto asMod = cast(ir.Module) previous.node;
	assert(asMod !is null);

	foreach (mod; asMod.myScope.importedModules) {
		auto store = mod.myScope.getStore(name);
		if (store !is null) {
			return ensureResolved(lp, store);
		}

		/// Check publically imported modules.
		foreach (i, submod; mod.myScope.importedModules) {
			if (mod.myScope.importedAccess[i] == ir.Access.Public) {
				store = submod.myScope.getStore(name);
				if (store !is null) {
					return ensureResolved(lp, store);
				}
			}
		}
	}

	/// @todo Error if we found multiple matches in importedScopes.

	return null;
}

/**
 * Helper functions that looksup a type and throws compiler errors
 * if it is not found or the found identifier is not a type.
 */
ir.Type lookupType(LanguagePass lp, ir.Scope _scope, ir.QualifiedName id)
{
	auto store = lookup(lp, _scope, id);

	auto loc = id.identifiers[$-1].location;
	auto name = id.identifiers[$-1].value;
	return ensureType(_scope, loc, name, store);
}

/**
 * Retrive from the object module a store with the given name.
 * Throws: CompilerPanic on failure.
 * Returns: Always a valid value.
 */
ir.Store retrieveStoreFromObject(LanguagePass lp, Location loc, string name)
{
	auto s = lp.objectModule.myScope;
	auto store = lookup(lp, s, loc, name);
	if (store is null || store.node is null) {
		throw panic(loc, "couldn't locate object." ~ name);
	}
	return store;
}

ir.Function retrieveFunctionFromObject(LanguagePass lp, Location loc, string name)
{
	auto s = lp.objectModule.myScope;
	auto store = lookup(lp, s, loc, name);
	return ensureFunction(s, loc, name, store);
}

ir.Type retrieveTypeFromObject(LanguagePass lp, Location loc, string name)
{
	auto s = lp.objectModule.myScope;
	auto store = lookup(lp, s, loc, name);
	return ensureType(s, loc, name, store);
}

/**
 * Looks up a class in object.
 * Throws: CompilerPanic on failure
 */
ir.Class retrieveClassFromObject(LanguagePass lp, Location loc, string name)
{
	auto clazzStore = retrieveStoreFromObject(lp, loc, name);
	auto clazz = cast(ir.Class) clazzStore.node;
	if (clazz is null) {
		throw panic(loc, format("object.%s is not a class.", name));
	}
	return clazz;
}

/**
 * Get the module in the bottom of the given _scope chain.
 * @throws CompilerPanic if no module at bottom of chain.
 */
ir.Module getModuleFromScope(ir.Scope _scope)
{
	while (_scope !is null) {
		auto m = cast(ir.Module)_scope.node;
		_scope = _scope.parent;

		if (m is null) {
			continue;
		}

		if (_scope !is null)
			throw panic(m.location, "module scope has parent");
		return m;
	}
	throw panic("scope chain without module base");
}

/**
 * Given a scope, get the oldest parent -- this is the module of that scope.
 * @throws CompilerPanic if no module at bottom of chain.
 */
ir.Scope getTopScope(ir.Scope _scope)
{
	auto m = getModuleFromScope(_scope);
	return m.myScope;
}

/**
 * Return the first scope and type that is thisable going down the
 * chain of containing scopes (_scope.parent field).
 *
 * Returns:
 *   True if we found a thisable type and its scope and type.
 */
bool getFirstThisable(ir.Scope _scope, out ir.Scope outScope, out ir.Type outType)
{
	while (_scope !is null) {
		auto node = _scope.node;
		if (node is null)
			throw panic("scope without owning node");

		auto asType = cast(ir.Type)node;
		auto asAggregate = cast(ir.Aggregate)node;

		if (asAggregate !is null) {
			outType = asType;
			outScope = asAggregate.myScope;
			return true;
		}

		_scope = _scope.parent;
	}
	return false;
}

/**
 * Return the first class scope and the class going down the chain
 * of containing scopes (_scope.parent field).
 *
 * Returns:
 *   True if we found a thisable type and its scope and type.
 */
bool getFirstClass(ir.Scope _scope, out ir.Scope outScope, out ir.Class outClass)
{
	while (_scope !is null) {
		auto node = _scope.node;
		if (node is null)
			throw panic("scope without owning node");

		auto asClass = cast(ir.Class)node;
		if (asClass !is null) {
			outClass = asClass;
			outScope = asClass.myScope;
			return true;
		}

		_scope = _scope.parent;
	}
	return false;
}

/**
 * Get the parents scope of the given scope if its a class scope.
 *
 * Returns:
 *   If the is a class and had a parents scope.
 */
bool getClassParentsScope(LanguagePass lp, ir.Scope _scope, out ir.Scope outScope, out ir.Class outClass)
{
	auto node = _scope.node;
	if (node is null)
		throw panic("scope without owning node");

	switch (node.nodeType) with (ir.NodeType) {
	case Function:
	case Module:
	case Import:
	case Struct:
	case Union:
	case UserAttribute:
	case BlockStatement:
	case Enum:
		return false;
	case Class:
		auto asClass = cast(ir.Class)node;
		assert(asClass !is null);

		lp.resolve(asClass);
		if (asClass.parentClass is null) {
			assert(asClass.parent is null);
			return false;
		}

		outClass = asClass.parentClass;
		outScope = asClass.parentClass.myScope;
		return true;
	default:
		throw panic(node.location, "unexpected nodetype");
	}
}

/**
 * Ensure that the given store is not null
 * and that it is non-overloaded Function.
 *
 * @return                The function pointed to by the store.
 * @throws CompilerError  Raises error should this not be the case.
 */
ir.Function ensureFunction(ir.Scope _scope, Location loc, string name, ir.Store store)
{
	if (store is null) {
		if (_scope is null) {
			throw makeFailedLookup(loc, name);
		} else {
			throw makeNotMember(loc, _scope.name, name);
		}
	}

	if (store.kind != ir.Store.Kind.Function || store.functions.length != 1) {
		throw makeExpected(loc, "function");
	}

	return store.functions[0];
}

/**
 * Ensures that the given store is not null,
 * and that the store node is a type.
 *
 * @return                The type pointed to by the store.
 * @throws CompilerError  Raises error should this not be the case.
 */
ir.Type ensureType(ir.Scope _scope, Location loc, string name, ir.Store store)
{
	if (store is null) {
		if (_scope is null) {
			throw makeFailedLookup(loc, name);
		} else {
			throw makeNotMember(loc, _scope.name, name);
		}
	}

	auto asType = cast(ir.Type) store.node;
	if (asType is null) {
		throw makeExpected(loc, name);
	}

	return asType;
}

/**
 * Ensures that the given store is not null,
 * and that the store node has or is a scope.
 *
 * @return                The scope of store type or the scope itself.
 * @throws CompilerError  Raises error should this not be the case.
 */
ir.Scope ensureScope(ir.Scope _scope, Location loc, string name, ir.Store store)
{
	if (store is null) {
		if (_scope is null) {
			throw makeFailedLookup(loc, name);
		} else {
			throw makeNotMember(loc, _scope.name, name);
		}
	}

	auto s = getScopeFromStore(store);
	if (s is null) {
		throw makeExpected(loc, "aggregate or scope");
	}
	return s;
}
