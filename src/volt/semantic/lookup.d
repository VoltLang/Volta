// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.lookup;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util : getScopeFromStore, getScopeFromType;
import volt.semantic.util : ensureResolved;

import volt.exceptions;
import volt.interfaces;
import volt.token.location;


/**
 * Look up an identifier in this scope only. 
 * Doesn't check parent scopes, parent classes, imports, or anywhere else but the
 * given scope.
 */
ir.Store lookupOnlyThisScope(Location loc, LanguagePass lp, ir.Scope _scope, string name)
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
ir.Store lookupAsThisScope(Location loc, LanguagePass lp, ir.Scope _scope, string name)
{
	ir.Class _class;
	do {
		auto ret = lookupOnlyThisScope(loc, lp, _scope, name);
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
ir.Store lookupAsImportScope(Location loc, LanguagePass lp, ir.Scope _scope, string name)
{
	auto store = lookupOnlyThisScope(loc, lp, _scope, name);
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
		if (i == last) {
			if (i == 0) {
				return lookup(id.location, lp, current, id.value);
			} else {
				return lookupAsThisScope(id.location, lp, current, id.value);
			}
		}

		if (i == 0) {
			current = lookupScope(id.location, lp, current, id.value);
		} else {
			current = lookupScopeAsThisScope(id.location, lp, current, id.value);
		}
	}
	assert(false);
}

/**
 * Look up a string chain, the first identifier is looked up globaly, and
 * the result is treated as a scope to lookup the next one should there be
 * more identifiers.
 */
ir.Store lookup(Location loc, LanguagePass lp, ir.Scope _scope, string[] names...)
{
	auto current = _scope;
	auto last = cast(int)names.length - 1;

	foreach (i, name; names) {
		if (i == last) {
			if (i == 0) {
				return lookup(loc, lp, current, name);
			} else {
				return lookupAsThisScope(loc, lp, current, name);
			}
		}

		if (i == 0) {
			current = lookupScope(loc, lp, current, name);
		} else {
			current = lookupScopeAsThisScope(loc, lp, current, name);
		}
	}
	assert(false);
}

/**
 * Look up an identifier in a scope and its parent scopes.
 * Returns the store or null if no match was found.
 */
ir.Store lookup(Location loc, LanguagePass lp, ir.Scope _scope, string name)
{
	ir.Scope current = _scope, previous = _scope;
	while (current !is null) {
		auto store = current.getStore(name);
		if (store !is null) {
			return ensureResolved(lp, store);
		}

		/// If this scope has a this variable, check it.
		/// @todo this should not be here
		auto _this = current.getStore("this");
		if (_this !is null) {
			auto asVar = cast(ir.Variable) _this.node;
			assert(asVar !is null);
			auto asTR = cast(ir.TypeReference) asVar.type;
			assert(asTR !is null);
			auto asStruct = cast(ir.Struct) asTR.type;
			auto asClass = cast(ir.Class) asTR.type;
			assert(asStruct !is null || asClass !is null);

			if (asClass !is null) {
				store = asClass.myScope.getStore(name);
			} else if (asStruct !is null) {
				store = asStruct.myScope.getStore(name);
			}
			if (store !is null) {
				return ensureResolved(lp, store);
			}
		}

		previous = current;
		current = current.parent;
	}

	if (_scope.parent !is null) {
		auto asClass = cast(ir.Class) _scope.parent.node;
		if (asClass is null) {
			asClass = cast(ir.Class) _scope.node;
		}
		if (asClass !is null) {
			auto currentClass = asClass.parentClass;
			while (currentClass !is null) {
				auto store = currentClass.myScope.getStore(name);
				if (store !is null) {
					return ensureResolved(lp, store);
				}
				currentClass = currentClass.parentClass;
			}
		}
	}

	auto asMod = cast(ir.Module) previous.node;
	assert(asMod !is null);


	foreach (mod; asMod.myScope.importedModules) {
		auto store = mod.myScope.getStore(name);
		if (store !is null) {
			return ensureResolved(lp, store);
		}


		import std.stdio;

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
	if (store is null) {
		auto loc = id.identifiers[$-1].location;
		auto name = id.identifiers[$-1].value;
		throw new CompilerError(loc, format("undefined identifier '%s'.", name));
	}
	if (store.kind != ir.Store.Kind.Type) {
		auto loc = id.identifiers[$-1].location;
		auto name = id.identifiers[$-1].value;
		throw new CompilerError(loc, format("%s used as type.", name));
	}
	auto asType = cast(ir.Type) store.node;
	assert(asType !is null);
	return asType;
}

/**
 * Lookup something with a scope in another scope.
 *
 * @throws CompilerError  If a Scope bearing thing couldn't be found in _scope.
 * @return                The Scope found in _scope.
 */
ir.Scope lookupScope(Location loc, LanguagePass lp, ir.Scope _scope, string name)
{
	auto store = lookup(loc, lp, _scope, name);
	if (store is null) {
		throw new CompilerError(loc, format("undefined identifier '%s'.", name));
	}

	auto s = getScopeFromStore(store);
	if (s is null) {
		throw new CompilerError(loc, format("'%s' is not a aggregate or scope", name));
	}
	return s;
}

/**
 * Lookup something with a scope in another thisable scope.
 * @see lookupAsThisScope.
 *
 * @throws CompilerError  If a Scope bearing thing couldn't be found in _scope.
 * @return                The Scope found in _scope.
 */
ir.Scope lookupScopeAsThisScope(Location loc, LanguagePass lp, ir.Scope _scope, string name)
{
	auto store = lookupAsThisScope(loc, lp, _scope, name);
	if (store is null) {
		throw new CompilerError(loc, format("'%s' has no member named '%s'.", _scope.name, name));
	}

	auto s = getScopeFromStore(store);
	if (s is null) {
		throw new CompilerError(loc, format("'%s' is not a aggregate or scope", name));
	}
	return s;
}

/**
 * Retrive from the object module a store with the given name.
 * Throws: CompilerPanic on failure.
 * Returns: Always a valid value.
 */
ir.Store retrieveStoreFromObject(Location loc, LanguagePass lp, ir.Scope _scope, string name)
{
	auto objectStore = lookup(loc, lp, _scope, "object");
	if (objectStore is null || objectStore.s is null) {
		throw CompilerPanic(loc, "couldn't access object module.");
	}
	auto store = lookup(loc, lp, objectStore.s, name);
	if (store is null || store.node is null) {
		throw CompilerPanic(loc, "couldn't locate object." ~ name);
	}
	return store;
}

/**
 * Look up object.TypeInfo.
 * Throws: CompilerPanic on failure.
 */
ir.Class retrieveTypeInfo(Location loc, LanguagePass lp, ir.Scope _scope)
{
	auto tinfoStore = retrieveStoreFromObject(loc, lp, _scope, "TypeInfo");
	auto tinfo = cast(ir.Class) tinfoStore.node;
	if (tinfo is null) {
		throw CompilerPanic(loc, "tinfo is wrong type.");
	}
	return tinfo;
}

/**
 * Look up object.Object.
 * Throws: CompilerPanic on failure.
 */
ir.Class retrieveObject(Location loc, LanguagePass lp, ir.Scope _scope)
{
	auto objStore = retrieveStoreFromObject(loc, lp, _scope, "Object");
	auto obj = cast(ir.Class) objStore.node;
	if (obj is null) {
		throw CompilerPanic(loc, "obj is wrong type.");
	}
	return obj;
}

/**
 * Look up object.AllocDg.
 * Throws: CompilerPanic on failure.
 */
ir.Variable retrieveAllocDg(Location loc, LanguagePass lp, ir.Scope _scope)
{

	auto allocDgStore = retrieveStoreFromObject(loc, lp, _scope, "allocDg");
	auto asVar = cast(ir.Variable) allocDgStore.node;
	if (asVar is null) {
		throw CompilerPanic(loc, "allocDg is wrong type.");
	}
	return asVar;
}

/**
 * Look up object.ArrayStruct.
 * Throws: CompilerPanic on failure.
 */
ir.Struct retrieveArrayStruct(Location loc, LanguagePass lp, ir.Scope _scope)
{
	auto arrayStore = retrieveStoreFromObject(loc, lp, _scope, "ArrayStruct");
	auto asStruct = cast(ir.Struct) arrayStore.node;
	if (asStruct is null) {
		throw CompilerPanic(asStruct.location, "object.ArrayStruct is wrong type.");
	}
	return asStruct;
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
			throw CompilerPanic(m.location, "module scope has parent");
		return m;
	}
	throw CompilerPanic("scope chain without module base");
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
			throw CompilerPanic("scope without owning node");

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
			throw CompilerPanic("scope without owning node");

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
		throw CompilerPanic("scope without owning node");

	switch (node.nodeType) with (ir.NodeType) {
	case Module:
	case Import:
	case Struct:
		return false;
	case Class:
		auto asClass = cast(ir.Class)node;
		assert(asClass !is null);

		lp.resolveClass(asClass);
		if (asClass.parentClass is null) {
			assert(asClass.parent is null);
			return false;
		}

		outClass = asClass.parentClass;
		outScope = asClass.parentClass.myScope;
		return true;
	default:
		throw CompilerPanic(node.location, "unexpected nodetype");
	}
}
