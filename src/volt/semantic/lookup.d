/*#D*/
// Copyright © 2012-2017, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Functions that encode the semantic code for looking up symbols.
 *
 * @ingroup semLookup
 */
module volt.semantic.lookup;

import watt.text.format : format;

import ir = volta.ir;
import volta.util.util : getScopeFromStore, getScopeFromType;

import volt.exceptions;
import volt.errors;
import volt.interfaces;
import volta.ir.location;
import volt.semantic.classify : realType, getMethodParent, isOrInheritsFrom;


/*!
 * @defgroup semLookup Lookup Semantics
 *
 * @ingroup semantic
 */

/*!
 * Look up an identifier in a scope and its parent scopes.
 * Returns the store or null if no match was found.
 *
 * @param     lp LanguagePass.
 * @param _scope The scope to look in.
 * @param    loc Location, for error messages.
 * @param   name The string to lookup.
 * @ingroup semLookup
 */
ir.Store lookup(LanguagePass lp, ir.Scope _scope, ref in Location loc, string name)
{
	ir.Scope current = _scope, previous = _scope;
	while (current !is null) {
		auto store = lookupAsThisScope(lp, current, /*#ref*/loc, name, current);
		if (store !is null) {
			return store;
		}

		previous = current;
		current = current.parent;
	}

	return walkImports(lp, /*#ref*/loc, _scope, name);
}

/*!
 * Look up a QualifiedName chain, the first identifier is looked up globaly,
 * and the result is treated as a scope to lookup the next one should there be
 * more identifiers.
 *
 * @param     lp LanguagePass.
 * @param _scope The scope to look in.
 * @param     qn QualifiedName to get idents from.
 * @ingroup semLookup
 */
ir.Store lookup(LanguagePass lp, ir.Scope _scope, ir.QualifiedName qn)
{
	auto last = qn.identifiers.length - 1;
	auto current = qn.leadingDot ? getTopScope(/*#ref*/qn.loc, _scope) : _scope;
	auto parentModule = getModuleFromScope(/*#ref*/qn.loc, _scope);

	foreach (i, id; qn.identifiers) {
		ir.Store store;
		string name = id.value;
		Location loc = id.loc;

		/*!
		 * The first lookup should be done globally the following
		 * in only that context. Leading dot taken care of above.
		 */
		if (i == 0) {
			store = lookup(lp, current, /*#ref*/loc, name);
			if (store is null) {
				return null;
			}
			auto asImport = cast(ir.Import) store.node;
			if (asImport !is null) {
				assert(asImport.targetModules.length > 0 && asImport.targetModules[0] !is null);
				current = asImport.targetModules[0].myScope;
			}
		} else {
			if (current.multibindScopes.length > 0) {
				store = lookupAsImportScopes(lp, current.multibindScopes, /*#ref*/loc, name);
			} else {
				store = lookupAsImportScope(lp, current, /*#ref*/loc, name);
			}
		}

		if (store is null) {
			if (i == last) {
				return null;
			} else if (i == 0) {
				throw makeFailedLookup(/*#ref*/loc, name);
			} else {
				auto t = cast(ir.Type)current.node;
				if (t is null) {
					throw makeFailedLookup(/*#ref*/loc, name);
				} else {
					throw makeNotMember(id, t, name);
				}
			}
		}

		// Need to resolve any aliases.
		store = ensureResolved(lp, store);

		if (i == last) {
			return store;
		} else {
			// Use improve error reporting by giving the scope.
			current = ensureScope(i == 0 ? null : current, /*#ref*/loc, name, store);
		}
	}
	assert(false);
}

/*!
 * Look up an identifier in the given scope only. Doesn't check parent scopes,
 * parent classes, imports, or anywhere else but the given scope.
 *
 * @param     lp LanguagePass.
 * @param _scope The scope to look in.
 * @param    loc Location, for error messages.
 * @param   name The string to lookup.
 * @ingroup semLookup
 */
ir.Store lookupInGivenScopeOnly(LanguagePass lp, ir.Scope _scope, ref in Location loc, string name)
{
	auto store = _scope.getStore(name);
	if (store is null) {
		return null;
	}
	return ensureResolved(lp, store);
}

/*!
 * Look up an identifier in this scope, in parent scopes (in
 * the case of classes), and in any imports for this scope.
 *
 * A usable scope for this function is retrieved from the
 * getFirstThisable function.
 *
 * @param      lp LanguagePass.
 * @param  _scope The scope to look in.
 * @param     loc Location, for error messages.
 * @param    name The string to lookup.
 * @param current The scope where the lookup took place.
 * @ingroup semLookup
 *
 * @todo actually lookup imports.
 */
ir.Store lookupAsThisScope(LanguagePass lp, ir.Scope _scope, ref in Location loc, string name, ir.Scope current)
{
	auto lookupModule = getModuleFromScope(/*#ref*/loc, current);

	// For `protected` tracking of the lookup.
	ir.Class callingMethodsParentClass = cast(ir.Class)current.node;
	bool originalScopeIsClass;

	if (callingMethodsParentClass !is null) {
		originalScopeIsClass = true;
	} else {
		originalScopeIsClass = getMethodParent(current, /*#out*/callingMethodsParentClass);
	}

	// Walk the class chain.
	ir.Class _class = _scope.node.toClassChecked();
	do {
		auto ret = lookupAsImportScope(lp, _scope, /*#ref*/loc, name);
		if (ret is null) {
			continue;
		}
	
		if (lookupModule !is getModuleFromScope(/*#ref*/loc, ret.parent)) {
			bool classLookup;
			if (originalScopeIsClass) {
				classLookup = isOrInheritsFrom(callingMethodsParentClass, _class);
			}
			// @todo https://trello.com/c/6ZNd3G9D/398-lookupd
			checkAccess(/*#ref*/loc, name, ret, classLookup);
		}

		return ensureResolved(lp, ret);

	} while (getClassParentsScope(lp, _scope, /*#out*/_scope, /*#out*/_class));

	return null;
}

/*!
 * Lookup in this scope and parent class scopes, if any.
 *
 * Does not consult imports of any kind.
 *
 * @param     lp LanguagePass.
 * @param _scope The scope to look in.
 * @param    loc Location, for error messages.
 * @param   name The string to lookup.
 * @Returns The store or null if no match was found.
 *
 * @ingroup semLookup
 */
ir.Store lookupOnlyThisScopeAndClassParents(LanguagePass lp, ir.Scope _scope, ref in Location loc, string name)
{
	ir.Class _class;
	do {
		auto ret = lookupInGivenScopeOnly(lp, _scope, /*#ref*/loc, name);
		if (ret !is null)
			return ensureResolved(lp, ret);
	} while (getClassParentsScope(lp, _scope, /*#out*/_scope, /*#out*/_class));

	return null;
}

/*!
 * Lookup up as identifier in this scope, and any public imports.
 *
 * Used for rebinding imports.
 *
 * @param     lp LanguagePass.
 * @param _scope The scope to look in.
 * @param    loc Location, for error messages.
 * @param   name The string to lookup.
 * @Returns The store or null if no match was found.
 *
 * @ingroup semLookup
 */
ir.Store lookupAsImportScope(LanguagePass lp, ir.Scope _scope, ref in Location loc, string name)
{
	auto store = lookupInGivenScopeOnly(lp, _scope, /*#ref*/loc, name);
	if (store !is null) {
		return ensureResolved(lp, store);
	}

	WalkContext ctx;
	walkPublicImports(lp, /*#ref*/loc, /*#ref*/ctx, _scope, name);
	return walkGetStore(lp, /*#ref*/loc, /*#ref*/ctx, _scope, name);
}

/*!
 * Lookup an identifier in multiple scopes, as import scopes.
 *
 * @ingroup semLookup
 */
ir.Store lookupAsImportScopes(LanguagePass lp, ir.Scope[] scopes, ref in Location loc, string name)
{
	ir.Store retStore;
	foreach (_scope; scopes) {
		auto store = lookupInGivenScopeOnly(lp, _scope, /*#ref*/loc, name);
		if (store !is null) {
			if (retStore !is null && retStore !is store) {
				throw makeMultipleMatches(/*#ref*/loc, name);
			}
			retStore = ensureResolved(lp, store);
			continue;
		}
		WalkContext ctx;
		walkPublicImports(lp, /*#ref*/loc, /*#ref*/ctx, _scope, name);
		store = walkGetStore(lp, /*#ref*/loc, /*#ref*/ctx, _scope, name);
		if (store !is null) {
			if (retStore !is null && retStore !is store) {
				throw makeMultipleMatches(/*#ref*/loc, name);
			}
			retStore = store;
		}
	}
	return retStore;
}

/*
 *
 * Lookup helpers.
 *
 */

/*!
 * This function is used to retrive cached versions of helper functions.
 *
 * @param     lp LanguagePass.
 * @param _scope The scope to look in.
 * @param    loc Location, for error messages.
 * @param   name The string to lookup.
 * @Returns The found function or null.
 *
 * @ingroup semLookup
 */
ir.Function lookupFunction(LanguagePass lp, ir.Scope _scope, ref in Location loc, string name)
{
	// Lookup the copy function for this type of array.
	auto store = lookupInGivenScopeOnly(lp, _scope, /*#ref*/loc, name);
	if (store !is null && store.kind == ir.Store.Kind.Function) {
		assert(store.functions.length == 1);
		return store.functions[0];
	}
	return null;
}

/*!
 * Helper functions that looksup a type and throws compiler errors
 * if it is not found or the found identifier is not a type.
 *
 * @param     lp LanguagePass.
 * @param _scope The scope to look in.
 * @param     qn QualifiedName to get idents from.
 * @Returns The found type or null.
 *
 * @ingroup semLookup
 */
ir.Type lookupType(LanguagePass lp, ir.Scope _scope, ir.QualifiedName id)
{
	auto store = lookup(lp, _scope, id);

	// If we can't find it, try and generate a sensible error.
	if (store is null) {
		string lastName;
		foreach (ident; id.identifiers) {
			store = lookup(lp, _scope, /*#ref*/ident.loc, ident.value);
			if (store is null && lastName == "") {
				throw makeFailedLookup(ident, ident.value);
			} else if (store is null) {
				throw makeNotMember(/*#ref*/ident.loc, lastName, ident.value);
			}
			lastName = ident.value;
		}
	}

	auto loc = id.identifiers[$-1].loc;
	auto name = id.identifiers[$-1].value;
	return ensureType(_scope, /*#ref*/loc, name, store);
}


/*
 *
 * Public helpers.
 *
 */

/*!
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
	case MultiScope:
		return s;
	case Reserved:
		throw panic(s.node, "reserved store ident '%s' found.", s.name);
	}
}

/*!
 * Get the module in the bottom of the given _scope chain.
 *
 * @Throws CompilerPanic if no module at bottom of chain.
 */
ir.Module getModuleFromScope(ref in Location loc, ir.Scope _scope)
{
	while (_scope !is null) {
		auto m = cast(ir.Module)_scope.node;
		_scope = _scope.parent;

		if (m is null) {
			continue;
		}

		if (_scope !is null) {
			throw panic(/*#ref*/m.loc, "module scope has parent");
		}

		return m;
	}

	throw panic(/*#ref*/loc, "scope chain without module base");
}

/*!
 * Return the first class scope and the class going down the chain
 * of containing scopes (_scope.parent field).
 *
 * @Returns True if we found a thisable type and its scope and type.
 */
bool getFirstClass(ir.Scope _scope, out ir.Scope outScope, out ir.Class outClass)
{
	while (_scope !is null) {
		auto node = _scope.node;
		if (node is null) {
			throw panic("scope without owning node");
		}

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


private:


/*
 *
 * Scope walking helpers.
 *
 */

/*!
 * Given a scope, get the oldest parent -- this is the module of that scope.
 *
 * @Throws  CompilerPanic if no module at bottom of chain.
 * @Returns 
 */
ir.Scope getTopScope(ref in Location loc, ir.Scope _scope)
{
	auto m = getModuleFromScope(/*#ref*/loc, _scope);
	return m.myScope;
}

/*!
 * Return the first scope and type that is thisable going down the
 * chain of containing scopes (_scope.parent field).
 *
 * @Returns True if we found a thisable type and its scope and type.
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

/*!
 * Get the parents scope of the given scope if its a class scope.
 *
 * @Returns If the is a class and had a parents scope.
 */
bool getClassParentsScope(LanguagePass lp, ir.Scope _scope, out ir.Scope outScope, out ir.Class outClass)
{
	auto node = _scope.node;
	if (node is null) {
		throw panic("scope without owning node");
	}

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
		throw panic(/*#ref*/node.loc, format("unexpected nodetype %s", node.nodeType));
	}
}


/*
 *
 * Check helpers.
 *
 */

bool checkPrivateAndAdd(ref WalkContext ctx, ir.Module mod,
                                ir.Store store)
{
	if (store is null) {
		return false;
	}

	if (store.myScope !is null) {
		// If this is a private module, don't use it.
		auto asImport = cast(ir.Import) store.node;
		if (asImport !is null && mod !is asImport.targetModules[0] &&
		    asImport.access != ir.Access.Public &&
		    asImport.bind is null) {
			return false;
		}
	}

	if (store.importBindAccess == ir.Access.Public) {
		ctx.stores[store.uniqueId] = store;
		return true;
	} else {
		ctx.privateLookup = true;
		return false;
	}
}

/*!
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
			throw makeBadAccess(/*#ref*/loc, name, access);
		}
	}

	if (store.kind == ir.Store.Kind.Alias) {
		assert(store.node.nodeType == ir.NodeType.Alias);
	}
	auto alia = cast(ir.Alias)store.node;
	if (alia is null && store.originalNodes.length > 0) {
		alia = cast(ir.Alias)store.originalNodes[0];
		if (alia !is null && alia.access == ir.Access.Public) {
			// If it's a public alias, check the store it points at.
			alia = null;
		}
	}
	if (alia !is null) {
		if (alia.store.myAlias is null || alia.access != ir.Access.Public) {
			return check(alia.access);
		} else {
			return checkAccess(/*#ref*/loc, name, alia.store.myAlias, classParentLookup);
		}
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

/*
 *
 * Ensure function helpers.
 *
 */

/*!
 * Ensure that the given store is not null
 * and that it is non-overloaded Function.
 *
 * @return                The function pointed to by the store.
 * @throws CompilerError  Raises error should this not be the case.
 */
ir.Function ensureFunction(ir.Scope _scope, ref in Location loc, string name, ir.Store store)
{
	if (store is null) {
		if (_scope is null) {
			throw makeFailedLookup(/*#ref*/loc, name);
		} else {
			throw makeNotMember(/*#ref*/loc, _scope.name, name);
		}
	}

	if (store.kind != ir.Store.Kind.Function || store.functions.length != 1) {
		throw makeExpected(/*#ref*/loc, "function");
	}

	return store.functions[0];
}

/*!
 * Ensures that the given store is not null,
 * and that the store node is a type.
 *
 * @return                The type pointed to by the store.
 * @throws CompilerError  Raises error should this not be the case.
 */
ir.Type ensureType(ir.Scope _scope, ref in Location loc, string name, ir.Store store)
{
	if (store is null) {
		if (_scope is null) {
			throw makeFailedLookup(/*#ref*/loc, name);
		} else {
			throw makeNotMember(/*#ref*/loc, _scope.name, name);
		}
	}

	auto asType = cast(ir.Type) store.node;
	if (asType is null) {
		if (store.node.nodeType == ir.NodeType.Variable) {
			throw makeExpressionForNew(/*#ref*/loc, name);
		} else {
			throw makeError(/*#ref*/loc, format("expected type, got '%s'.", name));
		}
	}

	return asType;
}

/*!
 * Ensures that the given store is not null,
 * and that the store node has or is a scope.
 *
 * @return                The scope of store type or the scope itself.
 * @throws CompilerError  Raises error should this not be the case.
 */
ir.Scope ensureScope(ir.Scope _scope, ref in Location loc, string name, ir.Store store)
{
	if (store is null) {
		if (_scope is null) {
			throw makeFailedLookup(/*#ref*/loc, name);
		} else {
			throw makeNotMember(/*#ref*/loc, _scope.name, name);
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
		throw makeExpected(/*#ref*/loc, "aggregate or scope");
	}
	return s;
}


/*
 *
 * Imported module walking code.
 *
 */

struct WalkContext
{
	bool[ir.NodeID] pubChecked;

	ir.Store[ir.NodeID] stores;

	bool privateLookup;
}

ir.Store walkImports(LanguagePass lp, ref in Location loc,
                     ir.Scope _scope, string name)
{
	auto asMod = getModuleFromScope(/*#ref*/loc, _scope);
	bool privateLookup;
	WalkContext ctx;

	foreach (i, mod; asMod.myScope.importedModules) {
		auto store = mod.myScope.getStore(name);

		if (checkPrivateAndAdd(/*#ref*/ctx, mod, store)) {
			continue;
		}

		//! Check publically imported modules.
		walkPublicImports(lp, /*#ref*/loc, /*#ref*/ctx, mod.myScope, name);
	}

	return walkGetStore(lp, /*#ref*/loc, /*#ref*/ctx, _scope, name);
}

void walkPublicImports(LanguagePass lp, ref in Location loc, ref WalkContext ctx,
                       ir.Scope _scope, string name)
{
	foreach (i, submod; _scope.importedModules) {
		// Skip privatly imported modules.
		if (_scope.importedAccess[i] != ir.Access.Public) {
			continue;
		}

		// Have we already checked this import.
		if (submod.myScope.node.uniqueId in ctx.pubChecked) {
			continue;
		}
		ctx.pubChecked[submod.myScope.node.uniqueId] = true;

		// Look for a store in this module.
		auto store = submod.myScope.getStore(name);

		// If we find a store in the module we added to the context.
		if (store !is null) {
			checkPrivateAndAdd(/*#ref*/ctx, submod, store);  // @todo Is this needed? Can we remove it somehow?
			checkAccess(/*#ref*/loc, name, store);
			store = ensureResolved(lp, store);
		}

		// If not look for other public imports.
		if (store is null) {
			walkPublicImports(lp, /*#ref*/loc, /*#ref*/ctx, submod.myScope, name);
			continue;
		}
	}
}

ir.Store walkGetStore(LanguagePass lp, ref in Location loc, ref WalkContext ctx,
                      ir.Scope _scope, string name)
{
	// Get only unqiue stores.
	ir.Store[] stores = ctx.stores.values;

	// Helpful error message if you happen to bind to a private symbol.
	if (stores.length == 0 && ctx.privateLookup) {
		throw makeUsedBindFromPrivateImport(/*#ref*/loc, name);
	}

	// We found nothing.
	if (stores.length == 0) {
		return null;
	}

	// We only found one thing, return it.
	if (stores.length == 1) {
		checkAccess(/*#ref*/loc, name, stores[0]);
		return ensureResolved(lp, stores[0]);
	}

	// Merge functions into a single store.
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

			throw makeMultipleMatches(/*#ref*/loc, name);
		}
		if (currentParent !is null) {
			throw makeMultipleMatches(/*#ref*/loc, name);
		}
		fns ~= store.functions;
	}

	if (currentParent !is null) {
		checkAccess(/*#ref*/loc, name, stores[0]);
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
