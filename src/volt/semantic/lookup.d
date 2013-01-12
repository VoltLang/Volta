module volt.semantic.lookup;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.token.location;


/**
 * Look up an identifier in this scope only. 
 * Doesn't check parent scopes, parent classes, imports, or anywhere else but the
 * given scope.
 */
ir.Store lookupOnlyThisScope(ir.Scope _scope, string name, Location location)
{
	return _scope.getStore(name);
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
ir.Store lookupAsThisScope(ir.Scope _scope, string name, Location location)
{
	ir.Class _class;
	do {
		auto ret = lookupOnlyThisScope(_scope, name, location);
		if (ret !is null)
			return ret;
	} while (getClassParentsScope(_scope, _scope, _class));

	return null;
}

/**
 * Look up an identifier in a scope and its parent scopes.
 * Returns the store or null if no match was found.
 */
ir.Store lookup(ir.Scope _scope, string name, Location location)
{
	ir.Scope current = _scope, previous = _scope;
	while (current !is null) {
		auto store = current.getStore(name);
		if (store !is null) {
			return store;
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
				return store;
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
					return store;
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
			return store;
		}


		import std.stdio;

		/// Check publically imported modules.
		foreach (i, submod; mod.myScope.importedModules) {
			if (mod.myScope.importedAccess[i] == ir.Access.Public) {
				store = submod.myScope.getStore(name);
				if (store !is null) {
					return store;
				}
			}
		}
	}

	/// @todo Error if we found multiple matches in importedScopes.

	return null;
}

/**
 * Look up object.TypeInfo.
 * Throws: CompilerPanic on failure.
 */
ir.Struct retrieveTypeInfoStruct(Location location, ir.Scope _scope)
{
	auto objectStore = _scope.lookup("object", location);
	if (objectStore is null || objectStore.s is null) {
		throw CompilerPanic(location, "couldn't access object module.");
	}
	auto tinfoStore = objectStore.s.lookup("TypeInfo", location);
	if (tinfoStore is null || tinfoStore.node is null || tinfoStore.node.nodeType != ir.NodeType.Struct) {
		throw CompilerPanic(location, "couldn't locate object.TypeInfo lowered class.");
	}
	auto tinfo = cast(ir.Struct) tinfoStore.node;
	assert(tinfo !is null);
	return tinfo;
}

ir.Class retrieveTypeInfoClass(Location location, ir.Scope _scope)
{
	auto objectStore = _scope.lookup("object", location);
	if (objectStore is null || objectStore.s is null) {
		throw CompilerPanic(location, "couldn't access object module.");
	}
	auto tinfoStore = objectStore.s.lookup("TypeInfo", location);
	if (tinfoStore is null || tinfoStore.node is null || tinfoStore.node.nodeType != ir.NodeType.Class) {
		throw CompilerPanic(location, "couldn't locate object.TypeInfo class.");
	}
	auto tinfo = cast(ir.Class) tinfoStore.node;
	assert(tinfo !is null);
	return tinfo;
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
		auto asClass = cast(ir.Class)node;
		auto asStruct = cast(ir.Struct)node;

		/// @todo Interface.
		if (asClass !is null) {
			outType = asType;
			outScope = asClass.myScope;
			return true;
		} else if (asStruct !is null) {
			outType = asType;
			outScope = asStruct.myScope;
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
bool getClassParentsScope(ir.Scope _scope, out ir.Scope outScope, out ir.Class outClass)
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
