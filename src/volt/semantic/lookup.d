module volt.semantic.lookup;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.token.location;


/**
 * Lookup an identifier in the scope and only in this scope
 * not parents scops, not parent classes, and not in imported
 * modules in this or any other scopes.
 */
ir.Store lookupOnlyThisScope(ir.Scope _scope, string name)
{
	return _scope.getStore(name);
}

/**
 * Lookup an identifier in a scope and its parent scopes.
 * Returns the store or null if no match was found.
 *
 * @param decend Should parents scopes be concidered.
 * 
 * @todo Take a location.
 */
ir.Store lookup(ir.Scope _scope, string name)
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
			auto asPointer = cast(ir.PointerType) asVar.type;
			assert(asPointer !is null);
			auto asTR = cast(ir.TypeReference) asPointer.base;
			assert(asTR !is null);
			auto asStruct = cast(ir.Struct) asTR.type;
			assert(asStruct !is null);
			store = asStruct.myScope.getStore(name);
			if (store !is null) {
				return store;
			}
		}

		previous = current;
		current = current.parent;
	}

	if (_scope.parent !is null) {
		auto asClass = cast(ir.Class) _scope.parent.node;
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
	auto objectStore = _scope.lookup("object");
	if (objectStore is null || objectStore.s is null) {
		throw CompilerPanic(location, "couldn't access object module.");
	}
	auto tinfoStore = objectStore.s.lookup("TypeInfo");
	if (tinfoStore is null || tinfoStore.node is null || tinfoStore.node.nodeType != ir.NodeType.Struct) {
		throw CompilerPanic(location, "couldn't locate object.TypeInfo lowered class.");
	}
	auto tinfo = cast(ir.Struct) tinfoStore.node;
	assert(tinfo !is null);
	return tinfo;
}

ir.Class retrieveTypeInfoClass(Location location, ir.Scope _scope)
{
	auto objectStore = _scope.lookup("object");
	if (objectStore is null || objectStore.s is null) {
		throw CompilerPanic(location, "couldn't access object module.");
	}
	auto tinfoStore = objectStore.s.lookup("TypeInfo");
	if (tinfoStore is null || tinfoStore.node is null || tinfoStore.node.nodeType != ir.NodeType.Class) {
		throw CompilerPanic(location, "couldn't locate object.TypeInfo class.");
	}
	auto tinfo = cast(ir.Class) tinfoStore.node;
	assert(tinfo !is null);
	return tinfo;
}

