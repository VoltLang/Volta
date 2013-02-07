// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.aliasresolver;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.exceptions;

import volt.semantic.lookup;


/**
 * Resolves an alias, either setting the myalias field
 * or turning it into a type.
 */
void resolveAlias(LanguagePass lp, ir.Store s)
{
	auto a = cast(ir.Alias)s.node;
	if (a.type !is null) {
		// UserResolver will have resolved the TypeReference.
		return s.markAliasResolved(a.type);
	}

	ir.Store ret;
	if (s.s is s.parent) {
		// Normal alias.
		assert(a.id.identifiers.length == 1);
		ret = lookup(a.location, lp, s.s, a.id.identifiers[0].value);
	} else {
		// Import alias.
		assert(a.id.identifiers.length == 1);
		ret = lookupAsImportScope(a.location, lp, s.s, a.id.identifiers[0].value);
	}

	if (ret is null) {
		throw new CompilerError(a.location, "'" ~ a.id.toString ~ "' not found");
	}

	s.markAliasResolved(ret);
}
