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
		a.type = lp.resolve(s.s, a.type);
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
		throw makeFailedLookup(a, a.id.toString());
	}

	s.markAliasResolved(ret);
}

/**
 * Ensure that there are no unresolved TypeRefences in the given
 * type. Stops when encountering the first resolved TypeReference.
 */
ir.Type resolveType(LanguagePass lp, ir.Scope current, ir.Type type)
{
	switch (type.nodeType) with (ir.NodeType) {
	case PrimitiveType:
	case NullType:
		return type;
	case PointerType:
		auto pt = cast(ir.PointerType)type;
		pt.base = resolveType(lp, current, pt.base);
		return type;
	case ArrayType:
		auto at = cast(ir.ArrayType)type;
		at.base = resolveType(lp, current, at.base);
		return type;
	case StaticArrayType:
		auto sat = cast(ir.StaticArrayType)type;
		sat.base = resolveType(lp, current, sat.base);
		return type;
	case StorageType:
		auto st = cast(ir.StorageType)type;
		// For auto and friends.
		if (st.base is null) {
			return type;
		}
		st.base = resolveType(lp, current, st.base);
		return type;
	case FunctionType:
		auto ft = cast(ir.FunctionType)type;
		ft.ret = resolveType(lp, current, ft.ret);
		foreach (ref p; ft.params) {
			p = resolveType(lp, current, p);
		}
		return type;
	case DelegateType:
		auto dt = cast(ir.DelegateType)type;
		dt.ret = resolveType(lp, current, dt.ret);
		foreach (ref p; dt.params) {
			p = resolveType(lp, current, p);
		}
		return type;
	case TypeReference:
		auto tr = cast(ir.TypeReference)type;
		lp.resolveTR(current, tr);

		if (cast(ir.Named)tr.type !is null) {
			return type;
		} else {
			resolveType(lp, current, tr.type);
			assert(tr.type !is null);

			auto ret = copyTypeSmart(tr.location, tr.type);
			ret.glossedName = tr.id.toString();
			return ret;
		}
	case Enum:
		auto e = cast(ir.Enum)type;
		lp.resolveNamed(e);
		return type;
	case AAType:
		auto at = cast(ir.AAType)type;
		lp.resolveAA(current, at);
		return type;
	case Class:
	case Struct:
	case Union:
	case TypeOf:
	case Interface:
		return type;
	default:
		throw panicUnhandled(type, ir.nodeToString(type));
	}
}

void resolveTR(LanguagePass lp, ir.Scope current, ir.TypeReference tr)
{
	if (tr.type !is null)
		return;

	tr.type = lookupType(lp, current, tr.id);
	assert(tr.type !is null);
}

void resolveAA(LanguagePass lp, ir.Scope current, ir.AAType at)
{
	at.value = lp.resolve(current, at.value);
	at.key = lp.resolve(current, at.key);

	auto base = at.key;

	auto tr = cast(ir.TypeReference)base;
	if (tr !is null) {
		base = tr.type;
	}

	if (base.nodeType == ir.NodeType.Struct ||
	    base.nodeType == ir.NodeType.Class) {
		return;
	}

	bool needsConstness;
	if (base.nodeType == ir.NodeType.ArrayType) {
		base = (cast(ir.ArrayType)base).base;
		needsConstness = true;
	} else if (base.nodeType == ir.NodeType.StaticArrayType) {
		base = (cast(ir.StaticArrayType)base).base;
		needsConstness = true;
	}

	auto prim = cast(ir.PrimitiveType)base;
	if (prim !is null &&
	    (!needsConstness || (prim.isConst || prim.isImmutable))) {
		return;
	}

	throw makeInvalidAAKey(at);
}

/**
 * Will make sure that the Enum's type is set, and
 * as such will resolve the first member since it
 * decides the type of the rest of the enum.
 */
void resolveEnum(LanguagePass lp, ir.Enum e)
{
	e.isResolved = true;

	e.base = lp.resolve(e.myScope, e.base);

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
		if (s.loweredNode is null) {
			createAggregateVar(lp, s);
		}

		foreach (n; s.members.nodes) {
			auto field = cast(ir.Variable)n;
			if (field is null ||
			    field.storage != ir.Variable.Storage.Field) {
				continue;
			}

			lp.resolve(s.myScope, field);
		}

		s.isActualized = true;

		if (s.loweredNode is null) {
			fileInAggregateVar(lp, s);
		}
}

void actualizeUnion(LanguagePass lp, ir.Union u)
{
		createAggregateVar(lp, u);

		size_t accum;
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
			auto s = size(lp, field.type);
			if (s > accum) {
				accum = s;
			}
		}

		u.totalSize = accum;
		u.isActualized = true;

		fileInAggregateVar(lp, u);
}
