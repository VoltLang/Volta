// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.util;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.exceptions;
import volt.interfaces;
import volt.token.location;
import volt.semantic.lookup;
import volt.semantic.typer : getExpType;


/// If e is a reference to a no-arg property function, turn it into a call.
/// Returns: the CallableType called, if any, null otherwise.
ir.CallableType propertyToCallIfNeeded(Location loc, LanguagePass lp, ref ir.Exp e, ir.Scope current, ir.Postfix[] postfixStack)
{
	auto asRef = cast(ir.ExpReference) e;
	if (asRef !is null) {
		if (asRef.rawReference) {
			return null;
		}
	}

	if (postfixStack.length > 0 && postfixStack[$-1].isImplicitPropertyCall) {
		return null;
	}

	auto t = getExpType(lp, e, current);
	if (t.nodeType == ir.NodeType.FunctionType || t.nodeType == ir.NodeType.DelegateType) {
		auto asCallable = cast(ir.CallableType) t;
		if (asCallable is null) {
			return null;
		}
		if (asCallable.isProperty && asCallable.params.length == 0) {
			auto postfix = buildCall(loc, e, null);
			postfix.isImplicitPropertyCall = true;
			e = postfix;
			return asCallable;
		}
	}
	return null;
}

ir.Type handleNull(ir.Type left, ref ir.Exp right, ir.Type rightType)
{
	if (rightType.nodeType == ir.NodeType.NullType) {
		auto constant = cast(ir.Constant) right;
		if (constant is null) {
			throw CompilerPanic(right.location, "non constant null");
		}

		while (true) switch (left.nodeType) with (ir.NodeType) {
		case PointerType:
			constant.type = buildVoidPtr(right.location);
			right = buildCastSmart(right.location, left, right);
			return copyTypeSmart(right.location, left);
		case ArrayType:
			right = buildArrayLiteralSmart(right.location, left);
			return copyTypeSmart(right.location, left);
		case TypeReference:
			auto tr = cast(ir.TypeReference) left;
			assert(tr !is null);
			left = tr.type;
			continue;
		case Class:
			auto _class = cast(ir.Class) left;
			if (_class !is null) {
				auto t = copyTypeSmart(right.location, _class);
				constant.type = t;
				return t;
			}
			goto default;
		default:
			string emsg = format("can't convert null into '%s'.", to!string(left.nodeType));
			throw new CompilerError(right.location, emsg);
		}
	}
	return null;
}

ir.Variable getThisVar(Location location, LanguagePass lp, ir.Scope _scope)
{
	auto thisStore = lookupOnlyThisScope(lp, _scope, location, "this");
	if (thisStore is null) {
		throw CompilerPanic(location, "need valid this for super.");
	}
	auto thisVar = cast(ir.Variable) thisStore.node;
	if (thisVar is null) {
		throw CompilerPanic(location, "this is not variable.");
	}
	return thisVar;
}

/**
 * Ensures that a Store is a resolved alias.
 */
ir.Store ensureResolved(LanguagePass lp, ir.Store s)
{
	if (s.kind == ir.Store.Kind.Alias) {
		lp.resolveAlias(s);
		while (s.myAlias !is null) {
			s = s.myAlias;
		}
		return s;
	} else if (s.kind == ir.Store.Kind.Value) {
		auto var = cast(ir.Variable)s.node;
		ensureResolved(lp, s.parent, var.type);
	} else if (s.kind == ir.Store.Kind.Function) {
		assert(s.functions.length == 1);
		auto fn = cast(ir.Function)s.functions[0];
		ensureResolved(lp, s.parent, fn.type);
	}
	return s;
}

/**
 * Ensure that there are no unresolved TypeRefences in the given
 * type. Stops when encountering the first resolved TypeReference.
 */
void ensureResolved(LanguagePass lp, ir.Scope current, ir.Type type)
{
	switch (type.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		return;
	case PointerType:
		auto pt = cast(ir.PointerType)type;
		return ensureResolved(lp, current, pt.base);
	case ArrayType:
		auto at = cast(ir.ArrayType)type;
		return ensureResolved(lp, current, at.base);
	case StaticArrayType:
		auto sat = cast(ir.StaticArrayType)type;
		return ensureResolved(lp, current, sat.base);
	case StorageType:
		auto st = cast(ir.StorageType)type;
		// For auto and friends.
		if (st.base is null)
			return;
		return ensureResolved(lp, current, st.base);
	case FunctionType:
		auto ft = cast(ir.FunctionType)type;
		ensureResolved(lp, current, ft.ret);
		foreach (p; ft.params) {
			ensureResolved(lp, current, p.type);
		}
		return;
	case DelegateType:
		auto dt = cast(ir.DelegateType)type;
		ensureResolved(lp, current, dt.ret);
		foreach (p; dt.params) {
			ensureResolved(lp, current, p.type);
		}
		return;
	case TypeReference:
		auto tr = cast(ir.TypeReference)type;
		return lp.resolveTypeReference(current, tr);
	case Class:
	case Struct:
	case TypeOf:
		return;
	default:
		string e = format("unhandled type: '%s'", to!string(type.nodeType));
		throw new CompilerError(type.location, e);
	}
}
