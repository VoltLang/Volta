module volt.semantic.lookup;

import ir = volt.ir.ir;

/**
 * Lookup an identifier in a scope and its parent scopes.
 * Returns the store or null if no match was found.
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
		previous = current;
		current = current.parent;
	}

	auto asMod = cast(ir.Module) previous.node;
	assert(asMod !is null);


	foreach (importedScope; asMod.importedScopes) {
		auto store = importedScope.getStore(name);
		if (store !is null) {
			return store;
		}
	}

	/// @todo Error if we found multiple matches in importedScopes.

	return null;
}

