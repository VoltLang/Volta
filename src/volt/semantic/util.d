/*#D*/
// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.util;

import watt.text.format : format;

import ir = volta.ir;
import volta.util.copy;
import volta.util.util;

import volt.errors;
import volt.interfaces;
import volta.ir.location;

import volt.semantic.typer : getExpType, getTypeidType;
import volt.semantic.lookup : lookup, lookupInGivenScopeOnly, getModuleFromScope;
import volt.semantic.context : Context;
import volt.semantic.classify : getParentFunction, realType, isFloatingPoint,
	typesEqual, inheritsFrom, isIntegral;
import volt.semantic.extyper : resolveStruct, resolveUnion;


/*!
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

/*!
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

	t = copyTypeSmart(/*#ref*/t.loc, t);
	t.isScope = false;
	t.isConst = false;
	t.isImmutable = false;
	return t;
}

/*!
 * Resolves AutoType to the given type.
 *
 * Copies the storage from the auto type and returns the result.
 */
ir.Type flattenAuto(ir.AutoType atype, ir.Type type)
{
	type = copyTypeSmart(/*#ref*/atype.loc, type);
	addStorage(type, atype);
	atype.explicitType = type;
	return type;
}

/*!
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
			throw panic(/*#ref*/stype.loc, "ref attached to non parameter");
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

/*!
 * Implicitly convert types to bools in conditional statements,
 * or error.
 *
 * This is the conversion used for the
 * `if`, `while`, `do`, and `for` statements.
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
		if (asPrimitive.type == ir.PrimitiveType.Kind.Void) {
			throw makeBadImplicitCast(exp, buildBool(/*#ref*/exp.loc), t);
		}
		break;
	case ir.NodeType.Class:
	case ir.NodeType.PointerType:
	case ir.NodeType.FunctionType:
	case ir.NodeType.DelegateType:
		t = getExpType(exp);
		auto cnst = buildConstantNull(/*#ref*/exp.loc, t);
		exp = buildBinOp(/*#ref*/exp.loc, ir.BinOp.Op.NotIs, exp, cnst);
		return;
	case ir.NodeType.ArrayType:
		auto zero = buildConstantSizeT(/*#ref*/exp.loc, ctx.lp.target, 0);
		exp = buildArrayLength(/*#ref*/exp.loc, ctx.lp.target, exp);
		exp = buildBinOp(/*#ref*/exp.loc, ir.BinOp.Op.Greater, exp, zero);
		return;
	case ir.NodeType.StaticArrayType:
	case ir.NodeType.AAType:
	case ir.NodeType.Interface:
	case ir.NodeType.Struct:
	case ir.NodeType.Union:
		throw makeBadImplicitCast(exp, buildBool(/*#ref*/exp.loc), t);
	default:
		throw panicUnhandled(exp, ir.nodeToString(exp));
	}

	exp = buildCastToBool(/*#ref*/exp.loc, exp);
}

/*!
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

/*!
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

void propagateStorage(ir.Type type)
{
	auto at = type.toArrayTypeChecked();
	if (at !is null) {
		addStorage(at.base, at);
		propagateStorage(at.base);
		return;
	}

	auto sat = type.toStaticArrayTypeChecked();
	if (sat !is null) {
		addStorage(sat.base, sat);
		propagateStorage(sat.base);
		return;
	}

	auto pt = type.toPointerTypeChecked();
	if (pt !is null) {
		addStorage(pt.base, pt);
		propagateStorage(pt.base);
		return;
	}

	auto aat = type.toAATypeChecked();
	if (aat !is null) {
		addStorage(aat.key, aat);
		addStorage(aat.value, aat);
		propagateStorage(aat.key);
		propagateStorage(aat.value);
		return;
	}
}

/*!
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

/*!
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
			if (handleIfNull(ctx, base, /*#ref*/val)) {
				changed = true;
			}
		}
		return changed;
	} else if (rightType.nodeType != ir.NodeType.NullType) {
		return false;
	}

	handleNull(ctx, left, /*#ref*/right, rightType);

	return true;
}

void handleNull(Context ctx, ir.Type left, ref ir.Exp right, ir.Type rightType)
{
	assert(rightType.nodeType == ir.NodeType.NullType);

	if (left.nodeType == ir.NodeType.AAType) {
		return;
	}

	auto constant = cast(ir.Constant) right;
	if (constant is null) {
		throw panic(/*#ref*/right.loc, "non constant null");
	}

	while (true) {
		switch (left.nodeType) with (ir.NodeType) {
		case PointerType:
			constant.type = buildVoidPtr(/*#ref*/right.loc);
			right = buildCastSmart(/*#ref*/right.loc, left, right);
			return;
		case ArrayType:
			right = buildArrayLiteralSmart(/*#ref*/right.loc, left);
			return;
		case FunctionType, DelegateType:
			auto t = copyTypeSmart(/*#ref*/right.loc, left);
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
				auto t = copyTypeSmart(/*#ref*/right.loc, _class);
				constant.type = t;
				return;
			}
			goto default;
		case Interface:
			auto _interface = cast(ir._Interface) left;
			if (_interface !is null) {
				auto t = copyTypeSmart(/*#ref*/right.loc, _interface);
				constant.type = t;
				return;
			}
			goto default;
		case AAType:
			auto mod = getModuleFromScope(/*#ref*/right.loc, ctx.current);
			if (!mod.magicFlagD) {
				goto default;
			}
			auto t = copyTypeSmart(/*#ref*/right.loc, left);
			constant.type = t;
			return;
		default:
			throw makeBadImplicitCast(right, rightType, left);
		}
	}
}

/*!
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
		ctx.lp, func.myScope, /*#ref*/n.loc, "this");
	if (thisStore is null) {
		if (func.kind == ir.Function.Kind.Nested) {
		    auto var = getThisVarNotNull(n, ctx, getParentFunction(func.myScope.parent));
		    panicAssert(n, var !is null);
		    return var;
		}
		if (thisStore is null) {
			// TODO This needs to be a better, not all lookups are calls.
			throw makeCallingWithoutInstance(/*#ref*/n.loc);
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

/*!
 * Returns a expression that is the this variable,
 * safely handles nested functions as well.
 *
 * Never returns null.
 */
ir.Exp getThisReferenceNotNull(ir.Node n, Context ctx, out ir.Variable thisVar)
{
	thisVar = getThisVarNotNull(n, ctx);
	return buildExpReference(/*#ref*/n.loc, thisVar, "this");
}

void addVarArgsVarsIfNeeded(LanguagePass lp, ir.Function func)
{
	if (func.type.hasVarArgs &&
	    !func.type.varArgsProcessed &&
	    func.hasBody &&
	    func.type.linkage == ir.Linkage.Volt) {
		auto tinfoClass = lp.tiTypeInfo;
		auto tr = buildTypeReference(/*#ref*/func.loc, tinfoClass, tinfoClass.name);
		auto array = buildArrayType(/*#ref*/func.loc, tr);
		auto argArray = buildArrayType(/*#ref*/func.loc, buildVoid(/*#ref*/func.loc));
		func.type.varArgsTypeids = buildVariable(/*#ref*/func.loc, array, ir.Variable.Storage.Function, "_typeids");
		func.type.varArgsTypeids.specialInitValue = true;
		ir.Status status;
		func.parsedBody.myScope.addValue(func.type.varArgsTypeids, "_typeids", /*#out*/status);
		if (status != ir.Status.Success) {
			throw panic(/*#ref*/func.loc, "value redefinition");
		}
		func.parsedBody.statements = func.type.varArgsTypeids ~ func.parsedBody.statements;
		func.type.varArgsArgs = buildVariable(/*#ref*/func.loc, argArray, ir.Variable.Storage.Function, "_args");
		func.type.varArgsArgs.specialInitValue = true;
		func.parsedBody.myScope.addValue(func.type.varArgsArgs, "_args", /*#out*/status);
		if (status != ir.Status.Success) {
			throw panic(/*#ref*/func.loc, "value redefinition");
		}
		func.parsedBody.statements = func.type.varArgsArgs ~ func.parsedBody.statements;
		func.type.varArgsProcessed = true;
	}
}

ir.Type[] expsToTypes(ir.Exp[] exps)
{
	auto types = new ir.Type[](exps.length);
	for (size_t i = 0; i < exps.length; i++) {
		types[i] = getExpType(exps[i]);
	}
	return types;
}

/*!
 * Gets a default value (The .init -- 0, or null, usually) for a given type.
 */
ir.Exp getDefaultInit(ref in Location loc, LanguagePass lp, ir.Type t)
{
	if (t is null) {
		throw panic(/*#ref*/loc, "null type");
	}
	switch (t.nodeType) {
	case ir.NodeType.TypeReference:
		auto tr = cast(ir.TypeReference) t;
		return getDefaultInit(/*#ref*/loc, lp, tr.type);
	case ir.NodeType.Enum:
		auto e = cast(ir.Enum) t;
		return getDefaultInit(/*#ref*/loc, lp, e.base);
	case ir.NodeType.PrimitiveType:
		auto pt = cast(ir.PrimitiveType) t;
		if (pt.type == ir.PrimitiveType.Kind.Float) {
			return buildConstantFloat(/*#ref*/loc, 0.0f);
		} else if (pt.type == ir.PrimitiveType.Kind.Double || pt.type == ir.PrimitiveType.Kind.Real) {
			return buildConstantDouble(/*#ref*/loc, 0.0);
		} else {
			return buildCastSmart(/*#ref*/loc, t, buildConstantInt(/*#ref*/loc, 0));
		}
	case ir.NodeType.ArrayType:
		return buildArrayLiteralSmart(/*#ref*/loc, t);
	case ir.NodeType.StaticArrayType:
		auto sat = cast(ir.StaticArrayType) t;
		auto exps = new ir.Exp[](sat.length);
		foreach (ref e; exps) {
			e = getDefaultInit(/*#ref*/loc, lp, sat.base);
		}
		return buildArrayLiteralSmart(/*#ref*/loc, t, exps);
	case ir.NodeType.PointerType:
	case ir.NodeType.Class:
	case ir.NodeType.DelegateType:
	case ir.NodeType.AAType:
	case ir.NodeType.Interface:
	case ir.NodeType.FunctionType:
		return buildConstantNull(/*#ref*/loc, t);
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
			exps ~= getDefaultInit(/*#ref*/loc, lp, var.type);
		}
		if (t.nodeType == ir.NodeType.Union) {
			return buildUnionLiteralSmart(/*#ref*/loc, _struct, exps);
		} else {
			return buildStructLiteralSmart(/*#ref*/loc, _struct, exps);
		}
	default:
		throw panicUnhandled(/*#ref*/loc, format("%s", t.nodeType));
	}
}

/*!
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
	auto prim = realt.toPrimitiveTypeChecked();
	auto pointer = realt.toPointerTypeChecked();
	auto named = cast(ir.Named)realt;

	if (postfix.identifier.value == "init" &&
		(named !is null || (prim is null && pointer is null))) {
		exp = getDefaultInit(/*#ref*/exp.loc, ctx.lp, type);
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
		exp = getDefaultInit(/*#ref*/exp.loc, ctx.lp, type);
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
			exp = buildConstantInt(/*#ref*/type.loc, max ? 8 : 0);
		} else {
			exp = buildConstantInt(/*#ref*/type.loc, max ? 4 : 0);
		}
		return true;
	}

	if (prim is null) {
		throw makeExpected(type, "primitive type");
	}

	final switch (prim.type) with (ir.PrimitiveType.Kind) {
	case Bool:
		exp = buildConstantInt(/*#ref*/prim.loc, max ? 1 : 0);
		break;
	case Ubyte, Char:
		exp = buildConstantInt(/*#ref*/prim.loc, cast(ubyte)(max ? 0xFF : 0));
		break;
	case Byte:
		exp = buildConstantInt(/*#ref*/prim.loc, cast(byte)(max ? 0x7F : 0x80));
		break;
	case Ushort, Wchar:
		exp = buildConstantInt(/*#ref*/prim.loc, cast(ushort)(max ? 0xFFFF : 0));
		break;
	case Short:
		exp = buildConstantInt(/*#ref*/prim.loc, cast(short)(max ? 0x7FFF : 0x8000));
		break;
	case Uint, Dchar:
		exp = buildConstantUint(/*#ref*/prim.loc, cast(uint)(max ? 0xFFFF_FFFFU : 0U));
		break;
	case Int:
		exp = buildConstantInt(/*#ref*/prim.loc, cast(int)(max ? 0x7FFF_FFFF : 0x8000_0000));
		break;
	case Ulong:
		exp = buildConstantUlong(/*#ref*/prim.loc, max ? 0xFFFF_FFFF_FFFF_FFFFUL : 0UL);
		break;
	case Long:
		exp = buildConstantLong(/*#ref*/prim.loc, max ? 0x7FFF_FFFF_FFFF_FFFFL : 0x8000_0000_0000_0000L);
		break;
	case Float:
		exp = buildConstantFloat(/*#ref*/prim.loc, max ? float.max : float.min_normal);
		break;
	case Double:
		exp = buildConstantDouble(/*#ref*/prim.loc, max ? double.max : double.min_normal);
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
	if (t.nodeType == ir.NodeType.TypeReference) {
		return t.toTypeReferenceFast().type;
	} else {
		return t;
	}
}

ir.AccessExp getSizeOf(ref in Location loc, LanguagePass lp, ir.Type type)
{
	auto unary = cast(ir.Unary)buildTypeidSmart(/*#ref*/loc, lp.tiTypeInfo, type);
	panicAssert(type, unary !is null);
	auto store = lookupInGivenScopeOnly(lp, lp.tiTypeInfo.myScope, /*#ref*/loc, "size");
	panicAssert(type, store !is null);
	auto var = cast(ir.Variable)store.node;
	panicAssert(type, var !is null);
	return buildAccessExp(/*#ref*/loc, unary, var);
}

ir.Type getCommonSubtype(ref in Location loc, ir.Type[] types)
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
			throw panic(/*#ref*/loc, "no common subtype");
		}
		candidate = _class.parentClass;
		count = countMatch(candidate);
	}

	return candidate;
}

/*!
 * Given a Node, if it's a Struct or a Union, resolve it.
 */
void resolveChildStructsAndUnions(LanguagePass lp, ir.Type rt)
{
	switch (rt.nodeType) {
	case ir.NodeType.Union:
		auto _u = cast(ir.Union)rt;
		resolveUnion(lp, _u);
		break;
	case ir.NodeType.Struct:
		auto _s = cast(ir.Struct)rt;
		resolveStruct(lp, _s);
		break;
	case ir.NodeType.TypeReference:
		panicAssert(rt, false);
		break;
	default:
		break;
	}
}

ir.Exp stripEnumIfEnum(ref ir.Exp e, out bool wasEnum)
{
	auto eref = cast(ir.ExpReference)e;
	if (eref is null) {
		return e;
	}
	if (eref.decl.nodeType != ir.NodeType.EnumDeclaration) {
		return e;
	}
	wasEnum = true;
	auto ed = cast(ir.EnumDeclaration)eref.decl;
	return ed.assign;
}
