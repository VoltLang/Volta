// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.lookup;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.util : getScopeFromStore, getScopeFromType;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.semantic.classify : realType, getMethodParent, isOrInheritsFrom;


/**
 * Look up an identifier in the given scope only. Doesn't check parent scopes,
 * parent classes, imports, or anywhere else but the given scope.
 */
ir.Store lookupInGivenScopeOnly(LanguagePass lp, ir.Scope _scope, Location loc, string name)
{
	auto store = _scope.getStore(name);
	if (store is null) {
		return null;
	}
	return ensureResolved(lp, store);
}

/**
 * Look up an identifier in this scope, in parent scopes (in
 * the case of classes), and in any imports for this scope.
 *
 * A usable scope for this function is retrieved from the
 * getFirstThisable function.
 *
 * Params:
 *   lp: LanguagePass.
 *   _scope: The scope to look in.
 *   loc: Location, for error messages.
 *   name: The string to lookup.
 *   current: The scope where the lookup took place.
 *
 * @todo actually lookup imports.
 */
ir.Store lookupAsThisScope(LanguagePass lp, ir.Scope _scope, Location loc, string name, ir.Scope current)
{
	ir.Class callingMethodsParentClass = cast(ir.Class)current.node;
	bool originalScopeIsClass;
	if (callingMethodsParentClass !is null) {
		originalScopeIsClass = true;
	} else {
		originalScopeIsClass = getMethodParent(current, callingMethodsParentClass);
	}
	auto lookupModule = getModuleFromScope(loc, current);
	ir.Class _class;
	do {
		auto ret = lookupAsImportScope(lp, _scope, loc, name);
		if (ret !is null) {
			if (lookupModule !is getModuleFromScope(loc, ret.parent)) {
				bool classLookup;
				if (originalScopeIsClass) {
					classLookup = isOrInheritsFrom(callingMethodsParentClass, _class);
				}
				checkAccess(loc, name, ret, classLookup);
			}
			return ensureResolved(lp, ret);
		}
	} while (getClassParentsScope(lp, _scope, _scope, _class));
	return null;
}

/**
 * Lookup in this scope and parent class scopes, if any.
 * Does not consult imports of any kind.
 */
ir.Store lookupOnlyThisScopeAndClassParents(LanguagePass lp, ir.Scope _scope, Location loc, string name)
{
	ir.Class _class;
	do {
		auto ret = lookupInGivenScopeOnly(lp, _scope, loc, name);
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
	auto store = lookupInGivenScopeOnly(lp, _scope, loc, name);
	if (store !is null) {
		return ensureResolved(lp, store);
	}

	PublicImportContext ctx;
	store = lookupPublicImportScope(lp, _scope, loc, name, ctx);
	if (store !is null) {
		return ensureResolved(lp, store);
	}

	return null;
}

private struct PublicImportContext
{
	bool[ir.NodeID] checked;
}

private ir.Store lookupPublicImportScope(LanguagePass lp, ir.Scope _scope,
                                         Location loc, string name,
                                         ref PublicImportContext ctx)
{
	foreach (i, submod; _scope.importedModules) {
		if (_scope.importedAccess[i] == ir.Access.Public) {
			auto store = submod.myScope.getStore(name);
			if (store !is null) {
				checkAccess(loc, name, store);
				return ensureResolved(lp, store);
			}
			if (submod.myScope.node.uniqueId in ctx.checked) {
				continue;
			}
			ctx.checked[submod.myScope.node.uniqueId] = true;
			store = lookupPublicImportScope(lp, submod.myScope, loc, name, ctx);
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
	auto last = qn.identifiers.length - 1;
	auto current = qn.leadingDot ? getTopScope(qn.loc, _scope) : _scope;
	auto parentModule = getModuleFromScope(qn.loc, _scope);

	foreach (i, id; qn.identifiers) {
		ir.Store store;
		string name = id.value;
		Location loc = id.loc;

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
		auto store = lookupAsThisScope(lp, current, loc, name, current);
		if (store !is null) {
			return store;
		}

		previous = current;
		current = current.parent;
	}

	auto asMod = getModuleFromScope(loc, _scope);
	bool privateLookup;

	ir.Store[] stores;
	foreach (i, mod; asMod.myScope.importedModules) {
		auto store = mod.myScope.getStore(name);
		if (store !is null && store.myScope !is null) {
			// If this is a private module, don't use it.
			auto asImport = cast(ir.Import) store.node;
			if (asImport !is null) {
				if (mod !is asImport.targetModule && asImport.access != ir.Access.Public && asImport.bind is null) {
					continue;
				}
			}
		}

		if (store !is null) {
			if (store.importBindAccess == ir.Access.Public) {
				stores ~= store;
			} else {
				privateLookup = true;
			}
			continue;
		}

		/// Check publically imported modules.
		PublicImportContext ctx;
		store = lookupPublicImportScope(lp, mod.myScope, loc, name, ctx);
		if (store !is null) {
			stores ~= store;
			continue;
		}
	}

	if (stores.length == 0 && privateLookup) {
		throw makeUsedBindFromPrivateImport(loc, name);
	}

	if (stores.length == 0) {
		return null;
	}

	// We're only interested in seeing each Store once. Remove duplicates.
	ir.Store[] uniqueStores;
	foreach (store; stores) {
		bool unique = true;
		foreach (ustore; uniqueStores) {
			if (ustore is store) {
				unique = false;
				break;
			}
		}
		if (unique) {
			uniqueStores ~= store;
		}
	}
	stores = uniqueStores;
	assert(stores.length >= 1);

	if (stores.length == 1) {
		checkAccess(loc, name, stores[0]);
		return ensureResolved(lp, stores[0]);
	}

	ir.Function[] fns;
	ir.Node currentParent;
	foreach (store; stores) {
		ensureResolved(lp, store);
		// @todo Error if we found multiple matches in importedScopes.
		if (store.functions.length == 0) {
			if (currentParent is null) {
				currentParent = getStoreNodeRealParent(lp, store);
				continue;
			}
			if (currentParent is getStoreNodeRealParent(lp, store)) {
				continue;
			}
			throw makeMultipleMatches(loc, name);
		}
		if (currentParent !is null) {
			throw makeMultipleMatches(loc, name);
		}
		fns ~= store.functions;
	}

	if (currentParent !is null) {
		checkAccess(loc, name, stores[0]);
		return ensureResolved(lp, stores[0]);
	}

	auto store = new ir.Store(_scope, fns, fns[0].name);
	ensureResolved(lp, store);
	return store;
}

ir.Node getStoreNodeRealParent(LanguagePass lp, ir.Store store)
{
	auto n = store.node;
	auto _alias = cast(ir.Alias)n;
	if (_alias !is null) {
		if (_alias.id !is null) {
			return getStoreNodeRealParent(lp, lookup(lp, _alias.lookScope, _alias.id));
		} else {
			return realType(_alias.type, false);
		}
	}
	auto ed = cast(ir.EnumDeclaration)n;
	if (ed !is null) {
		return realType(ed.type, false);
	}
	auto tr = cast(ir.TypeReference)n;
	if (tr !is null) {
		return realType(tr, false);
	}
	auto t = cast(ir.Type)n;
	if (t !is null) {
		return realType(t, false);
	}
	return n;
}

/**
 * Helper functions that looksup a type and throws compiler errors
 * if it is not found or the found identifier is not a type.
 */
ir.Type lookupType(LanguagePass lp, ir.Scope _scope, ir.QualifiedName id)
{
	auto store = lookup(lp, _scope, id);

	// If we can't find it, try and generate a sensible error.
	if (store is null) {
		string lastName;
		foreach (ident; id.identifiers) {
			store = lookup(lp, _scope, ident.loc, ident.value);
			if (store is null && lastName == "") {
				throw makeFailedLookup(ident, ident.value);
			} else if (store is null) {
				throw makeNotMember(ident.loc, lastName, ident.value);
			}
			lastName = ident.value;
		}
	}

	auto loc = id.identifiers[$-1].loc;
	auto name = id.identifiers[$-1].value;
	return ensureType(_scope, loc, name, store);
}

/**
* This function is used to retrive cached
* versions of helper functions.
*/
ir.Function lookupFunction(LanguagePass lp, ir.Scope _scope, Location loc, string name)
{
	// Lookup the copy function for this type of array.
	auto store = lookupInGivenScopeOnly(lp, _scope, loc, name);
	if (store !is null && store.kind == ir.Store.Kind.Function) {
		assert(store.functions.length == 1);
		return store.functions[0];
	}
	return null;
}

/**
 * Get the module in the bottom of the given _scope chain.
 * @throws CompilerPanic if no module at bottom of chain.
 */
ir.Module getModuleFromScope(ref in Location loc, ir.Scope _scope)
{
	while (_scope !is null) {
		auto m = cast(ir.Module)_scope.node;
		_scope = _scope.parent;

		if (m is null) {
			continue;
		}

		if (_scope !is null)
			throw panic(m.loc, "module scope has parent");
		return m;
	}
	throw panic(loc, "scope chain without module base");
}

/**
 * Given a scope, get the oldest parent -- this is the module of that scope.
 * @throws CompilerPanic if no module at bottom of chain.
 */
ir.Scope getTopScope(ref in Location loc, ir.Scope _scope)
{
	auto m = getModuleFromScope(loc, _scope);
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
	case Interface:
	case Union:
	case BlockStatement:
	case Enum:
	case Identifier:
		return false;
	case Class:
		auto asClass = cast(ir.Class)node;
		assert(asClass !is null);

		lp.resolveNamed(asClass);
		if (asClass.parentClass is null) {
			assert(asClass.parent is null);
			return false;
		}

		outClass = asClass.parentClass;
		outScope = asClass.parentClass.myScope;
		return true;
	default:
		throw panic(node.loc, format("unexpected nodetype %s", node.nodeType));
	}
}

/**
 * Resolves a store making sure the node it points to is
 * resolved, the function returns the store that a alias
 * is pointing to. Not the alias itself.
 */
ir.Store ensureResolved(LanguagePass lp, ir.Store s)
{
	final switch (s.kind) with (ir.Store.Kind) {
	case Merge:
		lp.resolve(s);
		assert(s.kind == Function);
		return s;
	case Alias:
		auto a = cast(ir.Alias)s.node;
		lp.resolve(a);
		while (s.myAlias !is null) {
			s = s.myAlias;
			return s;
		}
		return s;
	case Value:
		auto var = cast(ir.Variable)s.node;
		lp.resolve(s.parent, var);
		return s;
	case Function:
		foreach (func; s.functions) {
			lp.resolve(s.parent, func);
		}
		return s;
	case EnumDeclaration:
		auto ed = cast(ir.EnumDeclaration)s.node;
		assert(ed !is null);
		lp.resolve(s.parent, ed);
		return s;
	case Type:
		if (s.node.nodeType == ir.NodeType.Enum) {
			auto e = cast(ir.Enum)s.node;
			lp.resolveNamed(e);
		} else if (s.node.nodeType == ir.NodeType.Class) {
			auto c = cast(ir.Class)s.node;
			lp.resolveNamed(c);
		} else if (s.node.nodeType == ir.NodeType.Struct) {
			auto st = cast(ir.Struct)s.node;
			lp.resolveNamed(st);
		} else if (s.node.nodeType == ir.NodeType.Enum) {
			auto st = cast(ir.Enum)s.node;
			lp.resolveNamed(st);
		} else if (s.node.nodeType == ir.NodeType.Interface) {
			auto i = cast(ir._Interface)s.node;
			lp.resolveNamed(i);
		}
		return s;
	case Scope:
	case Template:
	case FunctionParam:
		return s;
	case Reserved:
		throw panic(s.node, "reserved store ident '%s' found.", s.name);
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
		throw makeError(loc, format("expected type, got '%s'.", name));
	}

	return asType;
}

/**
 * Check that the contents of store can be accessed (e.g. not private)
 */
void checkAccess(ref in Location loc, string name, ir.Store store, bool classParentLookup = false)
{
	if (store.importAlias) {
		return;
	}

	void check(ir.Access access)
	{
		if (access == ir.Access.Protected && classParentLookup) {
			return;
		}
		if (access == ir.Access.Private || access == ir.Access.Protected) {
			throw makeBadAccess(loc, name, access);
		}
	}

	if (store.kind == ir.Store.Kind.Alias) {
		assert(store.node.nodeType == ir.NodeType.Alias);
	}
	auto alia = cast(ir.Alias)store.originalNode;
	if (alia is null) {
		alia = cast(ir.Alias)store.node;
	}
	if (alia !is null) {
		return check(alia.access);
	}
	auto decl = cast(ir.Variable)store.node;
	if (decl !is null) {
		return check(decl.access);
	}
	auto func = cast(ir.Function)store.node;
	if (func !is null) {
		return check(func.access);
	}
	auto en = cast(ir.Enum)store.node;
	if (en !is null) {
		return check(en.access);
	}
	auto ed = cast(ir.EnumDeclaration)store.node;
	if (ed !is null) {
		return check(ed.access);
	}
	auto iface = cast(ir._Interface)store.node;
	if (iface !is null) {
		return check(iface.access);
	}
	auto agg = cast(ir.Aggregate)store.node;
	if (agg !is null && agg.access != ir.Access.Public) {
		return check(agg.access);
	}
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

	auto var = cast(ir.Variable) store.node;
	if (var !is null) {
		auto s = getScopeFromType(var.type);
		if (s !is null) {
			return s;
		}
	}

	auto s = getScopeFromStore(store);
	if (s is null) {
		throw makeExpected(loc, "aggregate or scope");
	}
	return s;
}
