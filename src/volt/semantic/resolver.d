// Copyright © 2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Borencrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.resolver;

import std.algorithm : sort;
import std.array : array;
import std.string : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.errors;
import volt.interfaces;

import volt.semantic.util;
import volt.semantic.classify;
import volt.semantic.typer : getExpType;


/*
 * These function do the actual resolving of various types
 * and constructs in the Volt Langauge. They should only be
 * used by the LanguagePass, and as such is not intended for
 * use of other code, that could should call the resolve
 * functions on the language pass instead.
 */

/**
 * Will make sure that the Enum's type is set, and
 * as such will resolve the first member since it
 * decides the type of the rest of the enum.
 */
void resolveEnum(LanguagePass lp, ir.Enum e)
{
	ensureResolved(lp, e.myScope.parent, e.base);
	e.resolved = true;

	// Do some extra error checking on out.
	scope (success) {
		if (!isIntegral(e.base)) {
			throw panic(e, "only integral enums are supported.");
		}
	}

	// If the base type isn't auto then we are done here.
	if (!isAuto(e.base))
		return;

	// Need to resolve the first member to set the type of the Enum.
	auto first = e.members[0];
	lp.resolve(e.myScope, first);

	assert(first !is null && first.assign !is null);
	auto type = getExpType(lp, first.assign, e.myScope);
	e.base = copyTypeSmart(e.location, type);
}
