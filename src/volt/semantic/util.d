// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.util;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volt.token.location;

import volt.semantic.typer : getExpType, getTypeidType;
import volt.semantic.lookup : lookup, lookupInGivenScopeOnly;
import volt.semantic.context : Context;
import volt.semantic.classify : getParentFunction, realType, isFloatingPoint,
	typesEqual, inheritsFrom;


/**
 * Turn a [|w|d]char into [ubyte|ushort|uint] type.
 */
ir.PrimitiveType charToInteger(ir.PrimitiveType pt)
{
	ir.PrimitiveType.Kind type;
	switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Char: type = Ubyte; break;
	case Wchar: type = Ushort; break;
	case Dchar: type = Uint; break;
	default:
		return pt;
	}

	pt = cast(ir.PrimitiveType) copyType(pt);
	pt.type = type;
	return pt;
}

/**
 * Remove the given types storage modifiers. Only the given type is modified,
 * any sub types are left unchanged. If no modification is made returns the
 * given type. Will do a deep copy if modification is needed.
 *
 * const(const(char)[]) -> const(char)[].
 */
ir.Type removeStorageFields(ir.Type t)
{
	if (!t.isConst && !t.isImmutable && !t.isScope) {
		return t;
	}

	t = copyTypeSmart(t.location, t);
	t.isScope = false;
	t.isConst = false;
	t.isImmutable = false;
	return t;
}

/**
 * Resolves AutoType to the given type.
 *
 * Copies the storage from the auto type and returns the result.
 */
ir.Type flattenAuto(ir.AutoType atype, ir.Type type)
{
	type = copyTypeSmart(atype.location, type);
	addStorage(type, atype);
	atype.explicitType = type;
	return type;
}

/**
 * Turn stype into a flag, and attach it to type.
 */
void flattenOneStorage(ir.StorageType stype, ir.Type type,
                       ir.CallableType ct, size_t ctIndex)
{
	final switch (stype.type) with (ir.StorageType.Kind) {
	case Const: type.isConst = true; break;
	case Immutable: type.isImmutable = true; break;
	case Scope: type.isScope = true; break;
	case Ref:
	case Out:
		if (ct is null) {
			throw panic(stype.location, "ref attached to non parameter");
		}
		if (stype.type == Ref) {
			ct.isArgRef[ctIndex] = true;
		} else {
			ct.isArgOut[ctIndex] = true;
		}
		break;
	case Auto: break;
	case Invalid: throw panic(stype, "invalid storage type");
	}
}

/**
 * Implicitly convert PrimitiveTypes to bools for 'if' and friends.
 *
 * Currently done for ifs but not other code.
 */
void implicitlyCastToBool(Context ctx, ref ir.Exp exp)
{
	auto t = getExpType(exp);
	auto type = realType(t);
	switch (type.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto asPrimitive = cast(ir.PrimitiveType) type;
		if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
			return;
		}
		break;
	case ir.NodeType.Class:
	case ir.NodeType.PointerType:
	case ir.NodeType.FunctionType:
	case ir.NodeType.DelegateType:
	case ir.NodeType.ArrayType:
		t = getExpType(exp);
		auto cnst = buildConstantNull(exp.location, t);
		exp = buildBinOp(exp.location, ir.BinOp.Op.NotIs, exp, cnst);
		return;
	case ir.NodeType.StaticArrayType:
	case ir.NodeType.AAType:
	case ir.NodeType.Interface:
	case ir.NodeType.Struct:
	case ir.NodeType.Union:
		throw makeBadImplicitCast(exp, buildBool(exp.location), t);
	default:
		throw panicUnhandled(exp, ir.nodeToString(exp));
	}

	exp = buildCastToBool(exp.location, exp);
}

/**
 * Return a array of postfixes from a tree of postfixes,
 * starting with the innermost child.
 */
ir.Postfix[] collectPostfixes(ir.Postfix postfix)
{
	if (postfix.child !is null && postfix.child.nodeType == ir.NodeType.Postfix) {
		return collectPostfixes(cast(ir.Postfix) postfix.child) ~ postfix;
	} else {
		return [postfix];
	}
}

/**
 * Get a Store or Type from the child of a pre-proceassed postfix chain.
 */
bool getIfStoreOrTypeExp(ir.Exp exp, out ir.Store store, out ir.Type type)
{
	// Get type or store from child, otherwise the child should be a value.
	if (auto se = cast(ir.StoreExp) exp) {
		store = se.store;
		type = cast(ir.Named) store.node;
	} else if (auto te = cast(ir.TypeExp) exp) {
		type = te.type;
	} else {
		// @TODO check that child is a value.
		return false;
	}

	return true;
}

/**
 * Given a type, return a type that will have every storage flag
 * that are nested within it, by going into array and pointer bases, etc.
 */
ir.Type accumulateStorage(ir.Type toType, ir.Type seed=null)
{
	if (seed is null) {
		seed = new ir.NullType();
	}
	addStorage(seed, toType);

	auto asArray = cast(ir.ArrayType)toType;
	if (asArray !is null) {
		return accumulateStorage(asArray.base, seed);
	}

	auto asPointer = cast(ir.PointerType)toType;
	if (asPointer !is null) {
		return accumulateStorage(asPointer.base, seed);
	}

	auto asAA = cast(ir.AAType)toType;
	if (asAA !is null) {
		seed = accumulateStorage(asAA.key, seed);
		return accumulateStorage(asAA.value, seed);
	}

	auto asAuto = cast(ir.AutoType)toType;
	if (asAuto !is null && asAuto.explicitType !is null) {
		return accumulateStorage(asAuto.explicitType, seed);
	}

	return seed;
}

/**
 * This handles implicitly typing null.
 * Generic function used by assign and other functions.
 */
bool handleIfNull(Context ctx, ir.Type left, ref ir.Exp right)
{
	auto rightType = getExpType(right);
	auto aliteral = cast(ir.LiteralExp)right;
	if (aliteral !is null) {
		ir.Type base;
		auto atype = cast(ir.ArrayType)realType(aliteral.type);
		if (atype !is null) {
			base = atype.base;
		}
		auto stype = cast(ir.StaticArrayType)realType(aliteral.type);
		if (stype !is null) {
			base = stype.base;
		}
		bool changed;
		foreach (ref val; aliteral.exps) {
			if (handleIfNull(ctx, base, val)) {
				changed = true;
			}
		}
		return changed;
	} else if (rightType.nodeType != ir.NodeType.NullType) {
		return false;
	}

	handleNull(left, right, rightType);

	return true;
}

void handleNull(ir.Type left, ref ir.Exp right, ir.Type rightType)
{
	assert(rightType.nodeType == ir.NodeType.NullType);

	auto constant = cast(ir.Constant) right;
	if (constant is null) {
		throw panic(right.location, "non constant null");
	}

	while (true) {
		switch (left.nodeType) with (ir.NodeType) {
		case PointerType:
			constant.type = buildVoidPtr(right.location);
			right = buildCastSmart(right.location, left, right);
			return;
		case ArrayType:
			right = buildArrayLiteralSmart(right.location, left);
			return;
		case FunctionType, DelegateType:
			auto t = copyTypeSmart(right.location, left);
			constant.type = t;
			return;
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
				return;
			}
			goto default;
		case Interface:
			auto _interface = cast(ir._Interface) left;
			if (_interface !is null) {
				auto t = copyTypeSmart(right.location, _interface);
				constant.type = t;
				return;
			}
			goto default;
		default:
			throw makeBadImplicitCast(right, rightType, left);
		}
	}
}

/**
 * Get the this variable for this function.
 *
 * May return the this var field on the nested struct,
 * use getThisReferenceNotNull if you want to safely
 * get a expression pointing to the thisVar.
 *
 * Never returns null.
 */
ir.Variable getThisVarNotNull(ir.Node n, Context ctx)
{
	// TODO Is there a function on the Context that is better?
	auto func = getParentFunction(ctx.current);
	if (func is null) {
		throw panic(n, "getThisVar called for scope outside of function.");
	}
	return getThisVarNotNull(n, ctx, func);
}

ir.Variable getThisVarNotNull(ir.Node n, Context ctx, ir.Function func)
{
	// TODO Field directly on ir.Function?
	auto thisStore = lookupInGivenScopeOnly(
		ctx.lp, func.myScope, n.location, "this");
	if (thisStore is null) {
		if (func.kind == ir.Function.Kind.Nested) {
		    auto var = getThisVarNotNull(n, ctx, getParentFunction(func.myScope.parent));
		    panicAssert(n, var !is null);
		    return var;
		}
		if (thisStore is null) {
			// TODO This needs to be a better, not all lookups are calls.
			throw makeCallingWithoutInstance(n.location);
		} else {
			assert(false);
		}
	}

	auto thisVar = cast(ir.Variable) thisStore.node;
	if (thisVar is null) {
		throw panic(n, "this is not variable.");
	}
	return thisVar;
}

/**
 * Returns a expression that is the this variable,
 * safely handles nested functions as well.
 *
 * Never returns null.
 */
ir.Exp getThisReferenceNotNull(ir.Node n, Context ctx, out ir.Variable thisVar)
{
	thisVar = getThisVarNotNull(n, ctx);
	return buildExpReference(n.location, thisVar, "this");
}

void replaceVarArgsIfNeeded(LanguagePass lp, ir.Function func)
{
	if (func.type.hasVarArgs &&
	    !func.type.varArgsProcessed &&
	    func.type.linkage == ir.Linkage.Volt) {
		auto tinfoClass = lp.tiTypeInfo;
		auto tr = buildTypeReference(func.location, tinfoClass, tinfoClass.name);
		auto array = buildArrayType(func.location, tr);
		auto argArray = buildArrayType(func.location, buildVoid(func.location));
		addParam(func.location, func, array, "_typeids");
		addParam(func.location, func, argArray, "_args");
		func.type.varArgsProcessed = true;
	}
}

/// Get a UserAttribute struct literal from a user Attribute.
ir.ClassLiteral getAttributeLiteral(ir.Annotation ua, ir.Attribute attr)
{
	auto cliteral = new ir.ClassLiteral();
	cliteral.location = attr.location;
	cliteral.type = copyTypeSmart(ua.layoutClass.location, ua.layoutClass);
	version (Volt) {
		cliteral.exps = new ir.Exp[](attr.arguments);
	} else {
		cliteral.exps = attr.arguments.dup;
	}

	if (attr.arguments.length > ua.fields.length) {
		throw makeWrongNumberOfArguments(attr, attr.arguments.length, ua.fields.length);
	} else {
		version (Volt) {
			cliteral.exps = new ir.Exp[](attr.arguments);
		} else {
			cliteral.exps = attr.arguments.dup;
		}
		foreach (field; ua.fields[attr.arguments.length .. $]) {
			if (field.assign is null) {
				throw makeExpected(field, "initialiser");
			}
			cliteral.exps ~= copyExp(field.assign);
		}
	}
	if (cliteral.exps.length != ua.fields.length) {
		throw panic(attr.location, "not every @interface field filled.");
	}
	return cliteral;
}

void replaceTraits(ref ir.Exp exp, ir.TraitsExp traits, LanguagePass lp, ir.Module thisModule, ir.Scope _scope)
{
	assert(traits.op == ir.TraitsExp.Op.GetAttribute);
	auto store = lookup(lp, _scope, traits.qname);
	auto uattr = cast(ir.Annotation) store.node;
	if (uattr is null) {
		throw makeFailedLookup(traits, traits.qname.toString());
	}

	ir.Attribute[] annotations;
	string name;

	store = lookup(lp, _scope, traits.target);

	switch (store.node.nodeType) with (ir.NodeType) {
	case Variable:
		auto var = cast(ir.Variable) store.node;
		annotations = var.annotations;
		name = var.name;
		break;
	case Function:
		auto func = cast(ir.Function) store.node;
		annotations = func.annotations;
		name = func.name;
		break;
	case Class:
		auto _class = cast(ir.Class) store.node;
		annotations = _class.annotations;
		name = _class.name;
		break;
	case Struct:
		auto _struct = cast(ir.Struct) store.node;
		annotations = _struct.annotations;
		name = _struct.name;
		break;
	default:
		assert(false, ir.nodeToString(store.node));
	}

	ir.Attribute annotation;
	for (int i = cast(int)annotations.length - 1; i >= 0; i--) {
		if (uattr is annotations[i].annotation) {
			annotation = annotations[i];
		}
	}
	if (annotation is null) {
		throw makeNotMember(exp.location, traits.target.toString(), traits.qname.toString());
	}

	exp = getAttributeLiteral(annotation.annotation, annotation);
}

ir.Type[] expsToTypes(ir.Exp[] exps)
{
	auto types = new ir.Type[](exps.length);
	for (size_t i = 0; i < exps.length; i++) {
		types[i] = getExpType(exps[i]);
	}
	return types;
}

/**
 * Gets a default value (The .init -- 0, or null, usually) for a given type.
 */
ir.Exp getDefaultInit(Location l, LanguagePass lp, ir.Type t)
{
	if (t is null) {
		throw panic(l, "null type");
	}
	switch (t.nodeType) {
	case ir.NodeType.TypeReference:
		auto tr = cast(ir.TypeReference) t;
		return getDefaultInit(l, lp, tr.type);
	case ir.NodeType.Enum:
		auto e = cast(ir.Enum) t;
		return getDefaultInit(l, lp, e.base);
	case ir.NodeType.PrimitiveType:
		auto pt = cast(ir.PrimitiveType) t;
		if (pt.type == ir.PrimitiveType.Kind.Float) {
			return buildConstantFloat(l, 0.0f);
		} else if (pt.type == ir.PrimitiveType.Kind.Double || pt.type == ir.PrimitiveType.Kind.Real) {
			return buildConstantDouble(l, 0.0);
		} else {
			return buildCastSmart(l, t, buildConstantInt(l, 0));
		}
	case ir.NodeType.ArrayType:
		return buildArrayLiteralSmart(l, t, []);
	case ir.NodeType.StaticArrayType:
		auto sat = cast(ir.StaticArrayType) t;
		auto exps = new ir.Exp[](sat.length);
		foreach (ref e; exps) {
			e = getDefaultInit(l, lp, sat.base);
		}
		return buildArrayLiteralSmart(l, t, exps);
	case ir.NodeType.PointerType:
	case ir.NodeType.Class:
	case ir.NodeType.DelegateType:
	case ir.NodeType.AAType:
	case ir.NodeType.Interface:
	case ir.NodeType.FunctionType:
		return buildConstantNull(l, t);
	case ir.NodeType.Struct:
	case ir.NodeType.Union:
		auto _struct = cast(ir.Aggregate) t;
		ir.Exp[] exps;
		foreach (n; _struct.members.nodes) {
			auto var = cast(ir.Variable) n;
			if (var is null || var is _struct.typeInfo ||
			    var.storage != ir.Variable.Storage.Field) {
				continue;
			}
			exps ~= getDefaultInit(l, lp, var.type);
		}
		if (t.nodeType == ir.NodeType.Union) {
			return buildUnionLiteralSmart(l, _struct, exps);
		} else {
			return buildStructLiteralSmart(l, _struct, exps);
		}
	default:
		throw panicUnhandled(l, format("%s", t.nodeType));
	}
}

/**
 * Handles <type>.<identifier>, like 'int.min' and the like.
 */
bool typeLookup(Context ctx, ref ir.Exp exp, ir.Type type)
{
	auto postfix = cast(ir.Postfix) exp;
	if (postfix is null || postfix.identifier is null) {
		return false;
	}
	auto value = postfix.identifier.value;

	bool max;
	auto realt = realType(type);
	auto prim = cast(ir.PrimitiveType)realt;
	auto pointer = cast(ir.PointerType)realt;
	auto named = cast(ir.Named)realt;

	if (named !is null && postfix.identifier.value == "init") {
		exp = getDefaultInit(exp.location, ctx.lp, type);
		return true;
	}

	if (prim is null && pointer is null) {
		return false;
	}

	auto eref = cast(ir.ExpReference) postfix.child;
	if (eref !is null) {
		// An instance. Let the normal lookup stuff generate the error message.
		return false;
	}

	switch (value) {
	case "init":
		exp = getDefaultInit(exp.location, ctx.lp, type);
		return true;
	case "max":
		max = true;
		break;
	case "min":
		if (prim !is null && isFloatingPoint(prim.type)) {
			throw makeExpected(type, "max, min_normal, or init");
		}
		break;
	case "min_normal":
		if (prim is null || !isFloatingPoint(prim.type)) {
			throw makeExpected(type, "max, min, or init");
		}
		break;
	default:
		return false;
	}

	if (pointer !is null) {
		if (ctx.lp.ver.isP64) {
			exp = buildConstantInt(type.location, max ? 8 : 0);
		} else {
			exp = buildConstantInt(type.location, max ? 4 : 0);
		}
		return true;
	}

	if (prim is null) {
		throw makeExpected(type, "primitive type");
	}

	final switch (prim.type) with (ir.PrimitiveType.Kind) {
	case Bool:
		exp = buildConstantInt(prim.location, max ? 1 : 0);
		break;
	case Ubyte, Char:
		exp = buildConstantInt(prim.location, max ? 255 : 0);
		break;
	case Byte:
		exp = buildConstantInt(prim.location, max ? 127 : -128);
		break;
	case Ushort, Wchar:
		exp = buildConstantInt(prim.location, max ? 65535 : 0);
		break;
	case Short:
		exp = buildConstantInt(prim.location, max? 32767 : -32768);
		break;
	case Uint, Dchar:
		exp = buildConstantUint(prim.location, max ? 4294967295U : 0U);
		break;
	case Int:
		exp = buildConstantInt(prim.location, max ? 2147483647 : -2147483648);
		break;
	case Ulong:
		exp = buildConstantUlong(prim.location, max ? 18446744073709551615UL : 0UL);
		break;
	case Long:
		/* We use a ulong here because -9223372036854775808 is not converted as a string
		 * with a - on the front, but just the number 9223372036854775808 that is in a
		 * Unary minus expression. And because it's one more than will fit in a long, we
		 * have to use the next size up.
		 */
		exp = buildConstantUlong(prim.location, max ? 9223372036854775807UL : -9223372036854775808UL);
		break;
	case Float:
		exp = buildConstantFloat(prim.location, max ? float.max : float.min_normal);
		break;
	case Double:
		exp = buildConstantDouble(prim.location, max ? double.max : double.min_normal);
		break;
	case Real, Void:
		throw makeExpected(prim, "integral type");
	case Invalid:
		throw panic(prim, "invalid primitive kind");
	}
	return true;
}

ir.Type ifTypeRefDeRef(ir.Type t)
{
	auto tref = cast(ir.TypeReference) t;
	if (tref is null) {
		return t;
	} else {
		return tref.type;
	}
}

ir.AccessExp getSizeOf(Location loc, LanguagePass lp, ir.Type type)
{
	auto unary = cast(ir.Unary)buildTypeidSmart(loc, lp, type);
	panicAssert(type, unary !is null);
	auto store = lookupInGivenScopeOnly(lp, lp.tiTypeInfo.myScope, loc, "size");
	panicAssert(type, store !is null);
	auto var = cast(ir.Variable)store.node;
	panicAssert(type, var !is null);
	return buildAccessExp(loc, unary, var);
}

ir.Type getCommonSubtype(Location l, ir.Type[] types)
{
	bool arrayElementSubtype(ir.Type element, ir.Type proposed)
	{
		if (typesEqual(element, proposed)) {
			return true;
		}
		auto aclass = cast(ir.Class) realType(element, false);
		auto bclass = cast(ir.Class) realType(proposed, false);
		if (aclass is null || bclass is null) {
			return false;
		}
		if (inheritsFrom(aclass, bclass)) {
			return true;
		}
		return false;
	}

	size_t countMatch(ir.Type t)
	{
		size_t count = 0;
		foreach (type; types) {
			if (arrayElementSubtype(type, t)) {
				count++;
			}
		}
		return count;
	}

	ir.Type candidate = types[0];
	size_t count = countMatch(candidate);
	while (count < types.length) {
		auto _class = cast(ir.Class) realType(candidate);
		if (_class is null) {
			return candidate;  // @todo non class common subtyping.
		}
		if (_class.parentClass is null) {
			// No common parent; volt is SI, this shouldn't happen.
			throw panic(l, "no common subtype");
		}
		candidate = _class.parentClass;
		count = countMatch(candidate);
	}

	return candidate;
}
