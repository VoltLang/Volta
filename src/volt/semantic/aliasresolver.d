// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.aliasresolver;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.errors;

import volt.semantic.lookup;
import volt.semantic.util : ensureResolved;


/**
 * Resolves an alias, either setting the myalias field
 * or turning it into a type.
 */
void resolveAlias(LanguagePass lp, ir.Store s)
{
	auto a = cast(ir.Alias)s.node;
	scope(exit) a.resolved = true;

	if (a.type !is null) {
		ensureResolved(lp, s.s, a.type);
		return s.markAliasResolved(a.type);
	}

	ir.Store ret;
	if (s.s is s.parent) {
		// Normal alias.
		ret = lookup(lp, s.s, a.id);
	} else {
		// Import alias.
		assert(a.id.identifiers.length == 1);
		ret = lookupAsImportScope(lp, s.s, a.location, a.id.identifiers[0].value);
	}

	if (ret is null) {
		throw makeFailedLookup(a, a.id.toString);
	}

	s.markAliasResolved(ret);
}
