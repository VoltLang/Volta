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
import volt.semantic.typeinfo;
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

void actualizeStruct(LanguagePass lp, ir.Struct s)
{
		createAggregateVar(lp, s);

		foreach (n; s.members.nodes) {
			auto field = cast(ir.Variable)n;
			if (field is null ||
			    field.storage != ir.Variable.Storage.Field) {
				continue;
			}

			lp.resolve(s.myScope, field);
		}

		s.isActualized = true;

		fileInAggregateVar(lp, s);
}

void actualizeUnion(LanguagePass lp, ir.Union u)
{
		createAggregateVar(lp, u);

		uint accum;
		foreach (n; u.members.nodes) {
			if (n.nodeType == ir.NodeType.Function) {
				throw makeExpected(n, "field");
			}
			auto field = cast(ir.Variable)n;
			if (field is null ||
			    field.storage != ir.Variable.Storage.Field) {
				continue;
			}

			lp.resolve(u.myScope, field);
			auto s = size(u.location, lp, field.type);
			if (s > accum) {
				accum = s;
			}
		}

		u.totalSize = accum;
		u.isActualized = true;

		fileInAggregateVar(lp, u);
}
