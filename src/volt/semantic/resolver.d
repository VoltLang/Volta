// Copyright © 2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Borencrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.resolver;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.errors;
import volt.interfaces;

import volt.semantic.util;
import volt.semantic.typer : getExpType;
import volt.semantic.lookup;
import volt.semantic.extyper;
import volt.semantic.context;
import volt.semantic.classify;
import volt.semantic.typeinfo;


/*
 * These function do the actual resolving of various types
 * and constructs in the Volt Langauge. They should only be
 * used by the LanguagePass, and as such is not intended for
 * use of other code, that could should call the resolve
 * functions on the language pass instead.
 */

/**
 * Resolves an alias, either setting the myalias field
 * or turning it into a type.
 */
void resolveAlias(LanguagePass lp, ir.Alias a)
{
	auto s = a.store;
	scope (success) {
		a.isResolved = true;
	}

	if (a.type !is null) {
		assert(s.lookScope is s.parent);
		resolveType(lp, s.parent, a.type);
		return s.markAliasResolved(a.type);
	}

	ir.Store ret;
	if (s.lookScope is s.parent) {
		// Normal alias.
		ret = lookup(lp, s.lookScope, a.id);
	} else {
		// Import alias.
		assert(a.id.identifiers.length == 1);
		ret = lookupAsImportScope(lp, s.lookScope, a.location, a.id.identifiers[0].value);
	}

	if (ret is null) {
		throw makeFailedLookup(a, a.id.toString());
	}

	s.markAliasResolved(ret);
}

/**
 * Will make sure that the Enum's type is set, and
 * as such will resolve the first member since it
 * decides the type of the rest of the enum.
 */
void resolveEnum(LanguagePass lp, ir.Enum e)
{
	e.isResolved = true;

	resolveType(lp, e.myScope, e.base);

	// Do some extra error checking on out.
	scope (success) {
		if (!isIntegral(e.base)) {
			throw panic(e, "only integral enums are supported.");
		}
	}

	// If the base type isn't auto then we are done here.
	if (!isAuto(e.base)) {
		return;
	}

	// Need to resolve the first member to set the type of the Enum.
	auto first = e.members[0];
	lp.resolve(e.myScope, first);

	assert(first !is null && first.assign !is null);
	auto type = getExpType(first.assign);
	e.base = realType(copyTypeSmart(e.location, type));
}

void resolveStruct(LanguagePass lp, ir.Struct s)
{
	auto done = lp.startResolving(s);
	scope (exit) {
		done();
	}

	lp.resolve(s.myScope.parent, s.userAttrs);

	if (s.loweredNode is null) {
		createAggregateVar(lp, s);
	}

	s.isResolved = true;

	// Resolve fields.
	foreach (n; s.members.nodes) {
		if (n.nodeType != ir.NodeType.Variable) {
			continue;
		}

		auto field = cast(ir.Variable)n;
		assert(field !is null);
		if (field.storage != ir.Variable.Storage.Field) {
			continue;
		}

		lp.resolve(s.myScope, field);
	}

	s.isActualized = true;

	if (s.loweredNode is null) {
		fileInAggregateVar(lp, s);
	}
}

void resolveUnion(LanguagePass lp, ir.Union u)
{
	auto done = lp.startResolving(u);
	scope (exit) {
		done();
	}

	lp.resolve(u.myScope.parent, u.userAttrs);

	createAggregateVar(lp, u);

	u.isResolved = true;

	// Resolve fields.
	size_t accum;
	foreach (n; u.members.nodes) {
		if (n.nodeType == ir.NodeType.Function) {
			throw makeExpected(n, "field");
		}

		if (n.nodeType != ir.NodeType.Variable) {
			continue;
		}

		auto field = cast(ir.Variable)n;
		assert(field !is null);
		if (field.storage != ir.Variable.Storage.Field) {
			continue;
		}
		lp.resolve(u.myScope, field);
		auto s = size(lp, field.type);
		if (s > accum) {
			accum = s;
		}
	}

	u.totalSize = accum;
	u.isActualized = true;

	fileInAggregateVar(lp, u);
}
