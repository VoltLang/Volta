// Copyright © 2012-2014, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2014, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.extyper;

import watt.conv : toString;
import watt.text.format : format;
import watt.text.string : replace;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.errors;
import volt.interfaces;
import volt.util.string;
import volt.token.location;

import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.visitor.prettyprinter;

import volt.semantic.util;
import volt.semantic.ctfe;
import volt.semantic.typer;
import volt.semantic.nested;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.context;
import volt.semantic.classify;
import volt.semantic.overload;
import volt.semantic.classresolver;
import volt.semantic.storageremoval;
import volt.semantic.userattrresolver;


/**
 * This handles the auto that has been filled in, removing the auto storage.
 */
void replaceAutoIfNeeded(ref ir.Type type)
{
	auto autotype = cast(ir.AutoType) type;
	if (autotype !is null && autotype.explicitType !is null) {
		type = autotype.explicitType;
		type = flattenStorage(type);
		addStorage(type, autotype);
	}
}

/**
 * This handles implicitly typing a struct literal.
 */
void handleIfStructLiteral(Context ctx, ir.Type left, ref ir.Exp right)
{
	ir.StructLiteral asLit;
	auto arrayLit = cast(ir.ArrayLiteral) right;
	if (arrayLit !is null) {
		auto array = cast(ir.ArrayType) realType(left);
		if (array is null) {
			return;
		}
		foreach (ref value; arrayLit.values) {
			handleIfStructLiteral(ctx, realType(array.base), value);
		}
		return;
	} else {
		asLit = cast(ir.StructLiteral) right;
	}

	if (asLit is null ||
	    asLit.type !is null) {
		return;
	}

	auto asStruct = cast(ir.Struct) realType(left);
	if (asStruct is null) {
		throw makeBadImplicitCast(right, getExpType(ctx.lp, right, ctx.current), left);
	}

	asLit.type = buildTypeReference(right.location, asStruct, asStruct.name);
}

/**
 * Does what the name implies.
 *
 * Checks if fn is null and is okay with more arguments the parameters.
 */
void appendDefaultArguments(Context ctx, ir.Location loc,
                            ref ir.Exp[] arguments, ir.Function fn)
{
	// Nothing to do.
	// Variadic functions may have more arguments then parameters.
	if (fn is null || arguments.length >= fn.params.length) {
		return;
	}

	ir.Exp[] overflow;
	foreach (p; fn.params[arguments.length .. $]) {
		if (p.assign is null) {
			throw makeExpected(loc, "default argument");
		}
		overflow ~= p.assign;
	}

	foreach (i, ee; overflow) {
		auto texp = cast(ir.TokenExp) ee;
		if (texp !is null) {
			texp.location = loc;
			arguments ~= texp;

			acceptExp(arguments[$-1], ctx.extyper);
		} else {
			assert(ee.nodeType == ir.NodeType.Constant);
			arguments ~= copyExp(loc, ee);
		}
	}
}


/*
 *
 * extypeAssign* code.
 *
 */

void extypeAssignTypeReference(Context ctx, ref ir.Exp exp,
                               ir.TypeReference tr)
{
	extypeAssign(ctx, exp, tr.type);
}

/**
 * Handles implicit pointer casts. To void*, immutable(T)* to const(T)*
 * T* to const(T)* and the like.
 */
void extypeAssignPointerType(Context ctx, ref ir.Exp exp,
                             ir.PointerType ptr, uint flag)
{
	ir.PointerType pcopy =
		cast(ir.PointerType) copyTypeSmart(exp.location, ptr);
	assert(pcopy !is null);

	auto type = ctx.overrideType !is null ? ctx.overrideType : realType(getExpType(ctx.lp, exp, ctx.current));

	auto rp = cast(ir.PointerType) type;
	if (rp is null) {
		throw makeBadImplicitCast(exp, type, pcopy);
	}
	ir.PointerType rcopy =
		cast(ir.PointerType) copyTypeSmart(exp.location, rp);
	assert(rcopy !is null);
	if (typesEqual(pcopy, rcopy)) {
		return;
	}

	auto pbase = realBase(cast(ir.PointerType)flattenStorage(pcopy));
	auto rbase = realBase(cast(ir.PointerType)flattenStorage(rcopy));
	if (typesEqual(pcopy, rcopy)) {
		return;
	}

	if (pbase.nodeType == ir.NodeType.PrimitiveType) {
		auto asPrimitive = cast(ir.PrimitiveType) pbase;
		assert(asPrimitive !is null);
		if (asPrimitive.type == ir.PrimitiveType.Kind.Void) {
			exp = buildCastSmart(pcopy, exp);
			return;
		}
	}

	if ((pbase.isConst && !rbase.isScope) ||
		(pbase.isImmutable && rbase.isConst) ||
		pbase.isScope && typesEqual(pbase, rbase, IgnoreStorage)) {
		exp = buildCastSmart(pcopy, exp);
		return;
	}

	throw makeBadImplicitCast(exp, type, pcopy);
}

/**
 * Implicit primitive casts (smaller to larger).
 */
void extypeAssignPrimitiveType(Context ctx, ref ir.Exp exp, ir.PrimitiveType lprim)
{
	auto rtype = getExpType(ctx.lp, exp, ctx.current);
	auto rprim = cast(ir.PrimitiveType) realType(rtype, true, true);
	if (rprim is null) {
		throw makeBadImplicitCast(exp, rtype, lprim);
	}

	if (typesEqual(lprim, rprim)) {
		return;
	}

	if (!isImplicitlyConvertable(rprim, lprim) &&
	    !fitsInPrimitive(lprim, exp)) {
		throw makeBadImplicitCast(exp, rprim, lprim);
	}

	exp = buildCastSmart(lprim, exp);
}

/**
 * Handles converting child classes to parent classes.
 */
void extypeAssignClass(Context ctx, ref ir.Exp exp, ir.Class _class)
{
	auto type = realType(getExpType(ctx.lp, exp, ctx.current), true, true);
	assert(type !is null);

	auto rightClass = cast(ir.Class) type;
	if (rightClass is null) {
		throw makeBadImplicitCast(exp, type, _class);
	}
	ctx.lp.resolveNamed(rightClass);

	/// Check for converting child classes into parent classes.
	if (_class !is null && rightClass !is null) {
		if (inheritsFrom(rightClass, _class)) {
			exp = buildCastSmart(exp.location, _class, exp);
			return;
		}
	}

	if (_class !is rightClass) {
		throw makeBadImplicitCast(exp, rightClass, _class);
	}
}

void extypeAssignEnum(Context ctx, ref ir.Exp exp, ir.Enum e)
{
	auto rtype = getExpType(ctx.lp, exp, ctx.current);
	if (typesEqual(e, rtype)) {
		return;
	}

	// TODO: This might need to be smarter.
	extypeAssignDispatch(ctx, exp, e.base);
}


/**
 * Handles assigning an overloaded function to a delegate.
 */
void extypeAssignCallableType(Context ctx, ref ir.Exp exp,
                              ir.CallableType ctype)
{
	auto rtype = ctx.overrideType !is null ? ctx.overrideType : realType(getExpType(ctx.lp, exp, ctx.current), true, true);
	if (typesEqual(ctype, rtype, IgnoreStorage)) {
		return;
	}
	if (rtype.nodeType == ir.NodeType.FunctionSetType) {
		auto fset = cast(ir.FunctionSetType) rtype;
		auto fn = selectFunction(ctx.lp, fset.set, ctype.params, exp.location);
		auto eRef = buildExpReference(exp.location, fn, fn.name);
		fset.set.reference = eRef;
		exp = eRef;
		replaceExpReferenceIfNeeded(ctx, null, exp, eRef);
		extypeAssignCallableType(ctx, exp, ctype);
		return;
	}
	throw makeBadImplicitCast(exp, rtype, ctype);
}

/**
 * Handles casting arrays of non mutably indirect types with
 * differing storage types.
 */
void extypeAssignArrayType(Context ctx, ref ir.Exp exp, ir.ArrayType atype, ref uint flag)
{
	auto alit = cast(ir.ArrayLiteral) exp;
	if (alit !is null && alit.values.length == 0) {
		exp = buildArrayLiteralSmart(exp.location, atype, []);
		return;
	}

	if (alit !is null) {
		auto aatype = cast(ir.ArrayType)realType(alit.type);
		panicAssert(exp, atype !is null);
		void nullCheckArrayLiteral(ir.ArrayLiteral lit)
		{
			foreach (ref val; lit.values) {
				auto lit2 = cast(ir.ArrayLiteral) val;
				if (lit2 !is null) {
					nullCheckArrayLiteral(lit2);
				} else {
					handleIfNull(ctx, aatype.base, val);
				}
			}
		}
		nullCheckArrayLiteral(alit);
	}

	auto astore = accumulateStorage(atype);
	auto rtype = ctx.overrideType !is null ? ctx.overrideType : realType(getExpType(ctx.lp, exp, ctx.current));

	auto stype = cast(ir.StaticArrayType) rtype;
	if (stype !is null && willConvertArray(atype, buildArrayType(exp.location, stype.base), flag, exp)) {
		exp = buildCastSmart(exp.location, atype, exp);
		return;
	}

	if (willConvertArray(atype, rtype, flag, exp)) {
		return;
	}

	throw makeBadImplicitCast(exp, rtype, atype);
}

void extypeAssignStaticArrayType(Context ctx, ref ir.Exp exp, ir.StaticArrayType atype, ref uint flag)
{
	ir.ArrayLiteral alit;
	void checkAlit()
	{
		if (alit is null) {
			throw makeExpected(exp.location, "array literal");
		}
		if (alit.values.length != atype.length) {
			throw makeStaticArrayLengthMismatch(exp.location, atype.length, alit.values.length);
		}
		auto ltype = realType(atype.base);
		foreach (ref e; alit.values) {
			acceptExp(e, ctx.extyper);
			extypeAssign(ctx, e, ltype);
		}
	}
	alit = cast(ir.ArrayLiteral) exp;
	if (alit is null) {
		auto t = realType(getExpType(ctx.lp, exp, ctx.current));
		if (typesEqual(t, atype)) {
			return;
		}
	}
	checkAlit();
	exp = buildInternalStaticArrayLiteralSmart(exp.location, atype, alit.values);
}

void extypeAssignAAType(Context ctx, ref ir.Exp exp, ir.AAType aatype)
{
	auto rtype = ctx.overrideType !is null ? ctx.overrideType : getExpType(ctx.lp, exp, ctx.current);
	if (exp.nodeType == ir.NodeType.AssocArray &&
	    typesEqual(aatype, rtype)) {
		return;
	}

	if (exp.nodeType == ir.NodeType.ArrayLiteral &&
	    (cast(ir.ArrayLiteral)exp).values.length == 0) {
		auto aa = new ir.AssocArray();
		aa.location = exp.location;
		aa.type = copyTypeSmart(exp.location, aatype);
		exp = aa;
		return;
	}

	if (rtype.nodeType == ir.NodeType.AAType) {
		// Allow assignment from vrt_aa_dup.
		auto unary = cast(ir.Unary) exp;
		if (unary !is null) {
			auto pfix = cast(ir.Postfix) unary.value;
			if (pfix !is null) {
				auto fn = cast(ir.FunctionType) realType(getExpType(ctx.lp, pfix.child, ctx.current));
				if (fn is ctx.lp.aaDup.type) {
					return;
				}
			}
		}
		// Otherwise, verboten.
		throw makeBadAAAssign(exp.location);
	}

	throw makeBadImplicitCast(exp, rtype, aatype);
}

void extypeAssignInterface(Context ctx, ref ir.Exp exp,
                           ir._Interface iface)
{
	auto type = realType(getExpType(ctx.lp, exp, ctx.current));

	auto eiface = cast(ir._Interface)type;
	if (eiface !is null) {
		if (typesEqual(iface, eiface)) {
			return;
		} else {
			throw panic(exp.location, "todo interface to different interface.");
		}
	}

	auto ctype = cast(ir.Class) type;
	if (ctype is null) {
		throw makeExpected(exp.location, "class");
	}
	bool checkInterface(ir._Interface i)
	{
		if (i is iface) {
			exp = buildCastSmart(exp.location, i, exp);
			return true;
		}
		foreach (piface; i.parentInterfaces) {
			if (checkInterface(piface)) {
				return true;
			}
		}
		return false;
	}
	bool checkClass(ir.Class _class)
	{
		if (_class is null) {
			return false;
		}
		foreach (i, classIface; _class.parentInterfaces) {
			if (checkInterface(classIface)) {
				return true;
			}
		}
		if (checkClass(_class.parentClass)) {
			return true;
		}
		return false;
	}
	if (checkClass(ctype)) {
		return;
	}
	throw makeBadImplicitCast(exp, type, iface);
}

/**
 * Yes really that name, no idea what this function does tho.
 */
void extypeAssignHandleAssign(Context ctx, ref ir.Type toType, ref ir.Exp exp,
                              ref uint toFlag, bool copying = false)
{
	auto rtype = getExpType(ctx.lp, exp, ctx.current);
	auto autotype = cast(ir.AutoType) toType;
	if (rtype.nodeType == ir.NodeType.FunctionSetType) {
		if (autotype !is null) {
			throw makeCannotInfer(exp.location);
		}
	}
	if (autotype !is null) {
		autotype.explicitType = copyTypeSmart(exp.location, rtype);
		panicAssert(exp, autotype.explicitType.nodeType != ir.NodeType.AutoType);
		if (!autotype.isConst && !autotype.isImmutable && !autotype.isScope) {
			addStorage(autotype, rtype);
		} else {
			addStorage(autotype.explicitType, autotype);
		}
	}
	auto originalRtype = rtype;
	auto originalTo = toType;
	auto lt = accumulateStorage(toType);
	auto rt = accumulateStorage(rtype);
	if (lt.isScope && ctx.isVarAssign) {
		exp = buildCastSmart(exp.location, toType, exp);
	} else if (rt.isConst && !effectivelyConst(lt) && mutableIndirection(originalTo) && !copying) {
		throw makeBadImplicitCast(exp, originalRtype, originalTo);
	} else if (mutableIndirection(originalTo) && !lt.isImmutable && rt.isScope && !lt.isScope && !copying) {
		throw makeBadImplicitCast(exp, originalRtype, originalTo);
	}
}

void extypeAssignDispatch(Context ctx, ref ir.Exp exp, ir.Type type,
                          bool copying = false)
{
	uint flag;
	extypeAssignHandleAssign(ctx, type, exp, flag, copying);
	switch (type.nodeType) {
	case ir.NodeType.AutoType:
		auto autotype = cast(ir.AutoType) type;
		extypeAssignDispatch(ctx, exp, autotype.explicitType, copying);
		break;
	case ir.NodeType.TypeReference:
		auto tr = cast(ir.TypeReference) type;
		extypeAssignTypeReference(ctx, exp, tr);
		break;
	case ir.NodeType.PointerType:
		auto ptr = cast(ir.PointerType) type;
		extypeAssignPointerType(ctx, exp, ptr, flag);
		break;
	case ir.NodeType.PrimitiveType:
		auto prim = cast(ir.PrimitiveType) type;
		extypeAssignPrimitiveType(ctx, exp, prim);
		break;
	case ir.NodeType.Class:
		auto _class = cast(ir.Class) type;
		extypeAssignClass(ctx, exp, _class);
		break;
	case ir.NodeType.Enum:
		auto e = cast(ir.Enum) type;
		extypeAssignEnum(ctx, exp, e);
		break;
	case ir.NodeType.FunctionType:
	case ir.NodeType.DelegateType:
		auto ctype = cast(ir.CallableType) type;
		extypeAssignCallableType(ctx, exp, ctype);
		break;
	case ir.NodeType.ArrayType:
		auto atype = cast(ir.ArrayType) type;
		extypeAssignArrayType(ctx, exp, atype, flag);
		break;
	case ir.NodeType.StaticArrayType:
		auto atype = cast(ir.StaticArrayType) type;
		extypeAssignStaticArrayType(ctx, exp, atype, flag);
		break;
	case ir.NodeType.AAType:
		auto aatype = cast(ir.AAType) type;
		extypeAssignAAType(ctx, exp, aatype);
		break;
	case ir.NodeType.Interface:
		auto iface = cast(ir._Interface) type;
		extypeAssignInterface(ctx, exp, iface);
		break;
	case ir.NodeType.Struct:
	case ir.NodeType.Union:
		auto rtype = getExpType(ctx.lp, exp, ctx.current);
		if (typesEqual(type, rtype)) {
			return;
		}
		throw makeBadImplicitCast(exp, rtype, type);
	default:
		throw panicUnhandled(exp, toString(type.nodeType));
	}
}

void extypeAssign(Context ctx, ref ir.Exp exp, ir.Type type,
                  bool copying = false)
{
	handleIfStructLiteral(ctx, type, exp);
	if (handleIfNull(ctx, type, exp)) return;

	extypeAssignDispatch(ctx, exp, type, copying);
}

void extypePass(Context ctx, ref ir.Exp exp, ir.Type type)
{
	auto ptr = cast(ir.PointerType) realType(type, true, true);
	// string literals implicitly convert to typeof(string.ptr)
	auto constant = cast(ir.Constant) exp;
	if (ptr !is null && constant !is null && constant._string.length != 0) {
		exp = buildAccess(exp.location, exp, "ptr");
	}
	extypeAssign(ctx, exp, type);
}


/*
 *
 * Here ends extypeAssign* code.
 *
 */

/**
 * If qname has a child of name leaf, returns an expression looking it up.
 * Otherwise, null is returned.
 */
ir.Exp withLookup(Context ctx, ref ir.Exp exp, ir.Scope current,
                  string leaf)
{
	ir.Exp access = buildAccess(exp.location, copyExp(exp), leaf);
	ir.Class _class;
	string emsg;
	ir.Scope eScope;
	auto type = realType(getExpType(ctx.lp, exp, current), false, true);
	if (exp.nodeType == ir.NodeType.Postfix) {
		retrieveScope(ctx.lp, type, cast(ir.Postfix)exp, eScope, _class, emsg);
	} else {
		retrieveScope(ctx.lp, type, cast(ir.Postfix)access, eScope, _class, emsg);
	}
	if (eScope is null) {
		throw makeBadWithType(exp.location);
	}
	auto store = lookupInGivenScopeOnly(ctx.lp, eScope, exp.location, leaf);
	if (store is null) {
		return null;
	}
	if (exp.nodeType == ir.NodeType.IdentifierExp) {
		extypePostfix(ctx, access, cast(ir.Postfix) access, null);
	}
	return access;
}

/**
 * Replace IdentifierExps with another exp, often ExpReference.
 *
 * Will ensure that the other exp is also accepted.
 */
void extypeIdentifierExp(Context ctx, ref ir.Exp e, ir.IdentifierExp i, ir.Exp parent)
{
	extypeIdentifierExpNoRevisit(ctx, e, i, parent);
	if (i !is e) {
		acceptExp(e, ctx.extyper);
	}
}

/**
 * No revisit version of the above function.
 */
void extypeIdentifierExpNoRevisit(Context ctx, ref ir.Exp e, ir.IdentifierExp i, ir.Exp parent)
{
	if (i.value == "super") {
		return rewriteSuper(ctx.lp, ctx.current, i, cast(ir.Postfix) parent);
	}

	auto current = i.globalLookup ? getModuleFromScope(i.location, ctx.current).myScope : ctx.current;

	// Rewrite expressions that rely on a with block lookup.
	ir.Exp rewriteExp;
	if (!i.globalLookup) foreach_reverse (withExp; ctx.withExps) {
		auto _rewriteExp = withLookup(ctx, withExp, current, i.value);
		if (_rewriteExp is null) {
			continue;
		}
		if (rewriteExp !is null) {
			throw makeWithCreatesAmbiguity(i.location);
		}
		rewriteExp = _rewriteExp;
		rewriteExp.location = e.location;
		// Continue to ensure no ambiguity.
	}
	if (rewriteExp !is null) {
		auto store = lookup(ctx.lp, current, i.location, i.value);
		if (store !is null && isStoreLocal(ctx.lp, ctx.current, store)) {
			throw makeWithCreatesAmbiguity(i.location);
		}
		e = rewriteExp;
		return;
	}
	// With rewriting is completed after this point, and regular lookup logic resumes.

	auto store = lookup(ctx.lp, current, i.location, i.value);
	if (store is null) {
		throw makeFailedLookup(i, i.value);
	}

	auto _ref = new ir.ExpReference();
	_ref.idents ~= i.value;
	_ref.location = i.location;

	final switch (store.kind) with (ir.Store.Kind) {
	case Value:
		auto var = cast(ir.Variable) store.node;
		assert(var !is null);
		if (!var.hasBeenDeclared &&
		    var.storage == ir.Variable.Storage.Function) {
			throw makeUsedBeforeDeclared(e, var);
		}
		_ref.decl = var;
		e = _ref;
		tagNestedVariables(ctx, var, store, e);
		return;
	case FunctionParam:
		auto fp = cast(ir.FunctionParam) store.node;
		assert(fp !is null);
		_ref.decl = fp;
		e = _ref;
		return;
	case Function:
		// Handle property.
		if (rewriteIfPropertyStore(e, null, i.value, parent, store)) {
			auto prop = cast(ir.PropertyExp) e;
			bool isMember = (prop.getFn !is null &&
					 prop.getFn.kind == ir.Function.Kind.Member) ||
			                (prop.setFns.length > 0 &&
			                 prop.setFns[0].kind == ir.Function.Kind.Member);
			if (!isMember) {
				return;
			}

			prop.child = buildIdentifierExp(i.location, "this");
			return;
		}

		foreach (fn; store.functions) {
			if (fn.nestedHiddenParameter !is null &&
			    store.functions.length > 1) {
				throw makeCannotOverloadNested(fn, fn);
			} else if (fn.nestedHiddenParameter !is null) {
				_ref.decl = store.functions[0];
				e = _ref;
				return;
			}
		}
		_ref.decl = buildSet(i.location, store.functions);
		e = _ref;
		return;
	case EnumDeclaration:
		auto ed = cast(ir.EnumDeclaration) store.node;
		assert(ed !is null);
		assert(ed.assign !is null);
		e = copyExp(ed.assign);
		return;
	case Template:
		throw panic(i, "template used as a value.");
	case Type:
		// Named types have a scope.
		auto named = cast(ir.Named) store.node;
		if (named !is null) {
			goto case Scope;
		}

		auto t = cast(ir.Type) store.node;
		assert(t !is null);

		auto te = new ir.TypeExp();
		te.location = i.location;
		//te.idents = [i.value];
		te.type = copyTypeSmart(i.location, t);
		e = te;
		return;
	case Scope:
		auto se = new ir.StoreExp();
		se.location = i.location;
		se.idents = [i.value];
		se.store = store;
		e = se;
		return;
	case Merge:
	case Alias:
		assert(false);
	}
}

bool replaceAAPostfixesIfNeeded(Context ctx, ir.Postfix postfix, ref ir.Exp exp)
{
	auto l = postfix.location;
	if (postfix.op == ir.Postfix.Op.Call) {
		assert(postfix.identifier is null);
		auto child = cast(ir.Postfix) postfix.child;
		if (child is null || child.identifier is null) {
			return false;
		}
		auto aa = cast(ir.AAType) realType(getExpType(ctx.lp, child.child, ctx.current));
		if (aa is null) {
			return false;
		}
		if (child.identifier.value != "get" && child.identifier.value != "remove") {
			return false;
		}
		bool keyIsArray = isArray(realType(aa.key));
		bool valIsArray = isArray(realType(aa.value));
		ir.ExpReference rtFn;
		ir.Exp[] args;
		if (child.identifier.value == "get") {
			if (postfix.arguments.length != 2) {
				return false;
			}
			args = new ir.Exp[](3);
			args[0] = copyExp(child.child);
			if (keyIsArray && valIsArray) {
				rtFn = buildExpReference(l, ctx.lp.aaGetAA, ctx.lp.aaGetAA.name);
			} else if (!keyIsArray && valIsArray) {
				rtFn = buildExpReference(l, ctx.lp.aaGetPA, ctx.lp.aaGetPA.name);
			} else if (keyIsArray && !valIsArray) {
				rtFn = buildExpReference(l, ctx.lp.aaGetAP, ctx.lp.aaGetAP.name);
			} else {
				rtFn = buildExpReference(l, ctx.lp.aaGetPP, ctx.lp.aaGetPP.name);
			}
			if (keyIsArray) {
				args[1] = buildCastSmart(l, buildArrayType(l, buildVoid(l)), postfix.arguments[0]);
			} else {
				args[1] = buildCastSmart(l, buildUlong(l), postfix.arguments[0]);
			}
			if (valIsArray) {
				args[2] = buildCastSmart(l, buildArrayType(l, buildVoid(l)), postfix.arguments[1]);
			} else {
				args[2] = buildCastSmart(l, buildUlong(l), postfix.arguments[1]);
			}
			exp = buildCastSmart(l, aa.value, buildCall(l, rtFn, args));
		} else if (child.identifier.value == "remove") {
			if (postfix.arguments.length != 1) {
				return false;
			}
			args = new ir.Exp[](2);
			args[0] = copyExp(child.child);
			if (keyIsArray) {
				rtFn = buildExpReference(l, ctx.lp.aaDeleteArray, ctx.lp.aaDeleteArray.name);
				args[1] = buildCastSmart(l, buildArrayType(l, buildVoid(l)), postfix.arguments[0]);
			} else {
				rtFn = buildExpReference(l, ctx.lp.aaDeletePrimitive, ctx.lp.aaDeletePrimitive.name);
				args[1] = buildCastSmart(l, buildUlong(l), postfix.arguments[0]);
			}
			exp = buildCall(l, rtFn, args);
		} else {
			panicAssert(child, false);
		}
		return true;
	}

	if (postfix.identifier is null) {
		return false;
	}
	auto aa = cast(ir.AAType) realType(getExpType(ctx.lp, postfix.child, ctx.current));
	if (aa is null) {
		return false;
	}
	ir.Exp[] arg = [copyExp(postfix.child)];
	switch (postfix.identifier.value) {
	case "keys":
		auto rtFn = buildExpReference(l, ctx.lp.aaGetKeys, ctx.lp.aaGetKeys.name);
		auto type = buildArrayType(l, aa.key);
		exp = buildCastSmart(l, type, buildCall(l, rtFn, arg));
		return true;
	case "values":
		auto rtFn = buildExpReference(l, ctx.lp.aaGetValues, ctx.lp.aaGetValues.name);
		auto type = buildArrayType(l, aa.value);
		exp = buildCastSmart(l, type, buildCall(l, rtFn, arg));
		return true;
	case "length":
		auto rtFn = buildExpReference(l, ctx.lp.aaGetLength, ctx.lp.aaGetLength.name);
		auto type = buildSizeT(l, ctx.lp);
		exp = buildDeref(l, buildCastSmart(l, buildPtrSmart(l, type), buildCall(l, rtFn, arg)));
		return true;
	case "rehash":
		auto rtFn = buildExpReference(l, ctx.lp.aaRehash, ctx.lp.aaRehash.name);
		exp = buildCall(l, rtFn, arg);
		return true;
	case "get":
		return false;
	case "remove":
		return false;
	default:
		auto store = lookup(ctx.lp, ctx.current, postfix.location, postfix.identifier.value);
		if (store is null || store.functions.length == 0) {
			throw makeBadBuiltin(postfix.location, aa, postfix.identifier.value);
		}
		return false;
	}
	assert(false);
}

void handleArgumentLabelsIfNeeded(Context ctx, ir.Postfix postfix,
                                  ir.Function fn, ref ir.Exp exp)
{
	if (fn is null) {
		return;
	}
	size_t[string] positions;
	ir.Exp[string] defaults;
	size_t defaultArgCount;
	foreach (i, param; fn.params) {
		defaults[param.name] = param.assign;
		positions[param.name] = i;
		if (param.assign !is null) {
			defaultArgCount++;
		}
	}

	if (postfix.argumentLabels.length == 0) {
		if (fn.type.forceLabel && fn.type.params.length > defaultArgCount) {
			throw makeForceLabel(exp.location, fn);
		}
		return;
	}

	if (postfix.argumentLabels.length != postfix.arguments.length) {
		throw panic(exp.location, "argument count and label count unmatched");
	}

	// If they didn't provide all the arguments, try filling in any default arguments.
	if (postfix.arguments.length < fn.params.length) {
		bool[string] labels;
		foreach (label; postfix.argumentLabels) {
			labels[label] = true;
		}
		foreach (arg, def; defaults) {
			if (def is null) {
				continue;
			}
			if (auto p = arg in labels) {
				continue;
			}
			postfix.arguments ~= def;
			postfix.argumentLabels ~= arg;
			postfix.argumentTags ~= ir.Postfix.TagKind.None;
		}
	}

	if (postfix.arguments.length != fn.params.length) {
		throw makeWrongNumberOfArguments(postfix, postfix.arguments.length, fn.params.length);
	}

	// Reorder arguments to match parameter order.
	for (size_t i = 0; i < postfix.argumentLabels.length; i++) {
		auto argumentLabel = postfix.argumentLabels[i];
		auto p = argumentLabel in positions;
		if (p is null) {
			throw makeUnmatchedLabel(postfix.location, argumentLabel);
		}
		auto labelIndex = *p;
		if (labelIndex == i) {
			continue;
		}
		auto tmp = postfix.arguments[i];
		auto tmp2 = postfix.argumentLabels[i];
		auto tmp3 = postfix.argumentTags[i];
		postfix.arguments[i] = postfix.arguments[labelIndex];
		postfix.argumentLabels[i] = postfix.argumentLabels[labelIndex];
		postfix.argumentTags[i] = postfix.argumentTags[labelIndex];
		postfix.arguments[labelIndex] = tmp;
		postfix.argumentLabels[labelIndex] = tmp2;
		postfix.argumentTags[labelIndex] = tmp3;
		i = 0;
	}
	exp = postfix;
}

/// Given a.foo, if a is a pointer to a class, turn it into (*a).foo.
private void dereferenceInitialClass(ir.Postfix postfix, ir.Type type)
{
	if (!isPointerToClass(type)) {
		return;
	}

	postfix.child = buildDeref(postfix.child.location, postfix.child);
}

// Hand check va_start(vl) and va_end(vl), then modify their calls.
private void rewriteVaStartAndEnd(Context ctx, ir.Function fn,
                                  ir.Postfix postfix, ref ir.Exp exp)
{
	if (fn is ctx.lp.vaStartFunc ||
	    fn is ctx.lp.vaEndFunc ||
	    fn is ctx.lp.vaCStartFunc ||
	    fn is ctx.lp.vaCEndFunc) {
		if (postfix.arguments.length != 1) {
			throw makeWrongNumberOfArguments(postfix, postfix.arguments.length, 1);
		}
		auto etype = getExpType(ctx.lp, postfix.arguments[0], ctx.current);
		auto ptr = cast(ir.PointerType) etype;
		if (ptr is null || !isVoid(ptr.base)) {
			throw makeExpected(postfix, "va_list argument");
		}
		if (!isLValue(postfix.arguments[0])) {
			throw makeVaFooMustBeLValue(postfix.arguments[0].location, (fn is ctx.lp.vaStartFunc || fn is ctx.lp.vaCStartFunc) ? "va_start" : "va_end");
		}
		postfix.arguments[0] = buildAddrOf(postfix.arguments[0]);
		if (fn is ctx.lp.vaStartFunc) {
			assert(ctx.currentFunction.params[$-1].name == "_args");
			postfix.arguments ~= buildAccess(postfix.location, buildExpReference(postfix.location, ctx.currentFunction.params[$-1], "_args"), "ptr");
		}
		if (ctx.currentFunction.type.linkage == ir.Linkage.Volt) {
			if (fn is ctx.lp.vaStartFunc) {
				exp = buildVaArgStart(postfix.location, postfix.arguments[0], postfix.arguments[1]);
				return;
			} else if (fn is ctx.lp.vaEndFunc) {
				exp = buildVaArgEnd(postfix.location, postfix.arguments[0]);
				return;
			} else {
				throw makeExpected(postfix.location, "volt va_args function.");
			}
		}
	}
}

private void rewriteVarargs(Context ctx,ir.CallableType asFunctionType,
                            ir.Postfix postfix)
{
	if (!asFunctionType.hasVarArgs ||
		asFunctionType.linkage != ir.Linkage.Volt) {
		return;
	}
	ir.ExpReference asExp;
	if (postfix.child.nodeType == ir.NodeType.Postfix) {
		assert(postfix.op == ir.Postfix.Op.Call);
		auto pfix = cast(ir.Postfix) postfix.child;
		assert(pfix !is null);
		assert(pfix.op == ir.Postfix.Op.CreateDelegate);
		assert(pfix.memberFunction !is null);
		asExp = pfix.memberFunction;
	}
	if (asExp is null) {
		asExp = cast(ir.ExpReference) postfix.child;
	}
	auto asFunction = cast(ir.Function) asExp.decl;
	assert(asFunction !is null);

	auto callNumArgs = postfix.arguments.length;
	auto funcNumArgs = asFunctionType.params.length - 2; // 2 == the two hidden arguments
	if (callNumArgs < funcNumArgs) {
		throw makeWrongNumberOfArguments(postfix, callNumArgs, funcNumArgs);
	}
	auto amountOfVarArgs = callNumArgs - funcNumArgs;
	auto argsSlice = postfix.arguments[0 .. funcNumArgs];
	auto varArgsSlice = postfix.arguments[funcNumArgs .. $];

	auto tinfoClass = ctx.lp.typeInfoClass;
	auto tr = buildTypeReference(postfix.location, tinfoClass, tinfoClass.name);
	tr.location = postfix.location;
	auto array = new ir.ArrayType();
	array.location = postfix.location;
	array.base = tr;

	auto typeidsLiteral = new ir.ArrayLiteral();
	typeidsLiteral.location = postfix.location;
	typeidsLiteral.type = array;

	int[] sizes;
	int totalSize;
	ir.Type[] types;
	foreach (i, _exp; varArgsSlice) {
		auto etype = getExpType(ctx.lp, _exp, ctx.current);
		if (ctx.lp.settings.internalD &&
		    realType(etype).nodeType == ir.NodeType.Struct) {
			warning(_exp.location, "passing struct to vaarg function");
		}
		auto typeId = buildTypeidSmart(postfix.location, etype);
		typeidsLiteral.values ~= typeId;
		types ~= etype;
		// TODO this probably isn't right.
		sizes ~= cast(int)size(ctx.lp, etype);
		totalSize += sizes[$-1];
	}

	postfix.arguments = argsSlice ~ typeidsLiteral ~ buildInternalArrayLiteralSliceSmart(postfix.location, buildArrayType(postfix.location, buildVoid(postfix.location)), types, sizes, totalSize, ctx.lp.memcpyFunc, varArgsSlice);
}

private void resolvePostfixOverload(Context ctx, ir.Postfix postfix,
                                    ir.ExpReference eref, ref ir.Function fn,
                                    ref ir.CallableType asFunctionType,
                                    ref ir.FunctionSetType asFunctionSet,
                                    bool reeval)
{
	if (eref is null) {
		throw panic(postfix.location, "expected expref");
	}
	asFunctionSet.set.reference = eref;
	fn = selectFunction(ctx.lp, ctx.current, asFunctionSet.set, postfix.arguments, postfix.location);
	eref.decl = fn;
	asFunctionType = fn.type;

	if (reeval) {
		replaceExpReferenceIfNeeded(ctx, null, postfix.child, eref);
	}
}

/**
 * Rewrite a call to a homogenous variadic if needed.
 * Makes individual parameters at the end into an array.
 */
private void rewriteHomogenousVariadic(Context ctx,
                                       ir.CallableType asFunctionType,
                                       ref ir.Exp[] arguments)
{
	if (!asFunctionType.homogenousVariadic || arguments.length == 0) {
		return;
	}
	auto i = asFunctionType.params.length - 1;
	auto etype = getExpType(ctx.lp, arguments[i], ctx.current);
	auto arr = cast(ir.ArrayType) asFunctionType.params[i];
	if (arr is null) {
		throw panic(arguments[0].location, "homogenous variadic not array type");
	}
	if (willConvert(etype, arr)) {
		return;
	}
	if (!typesEqual(etype, arr)) {
		auto exps = arguments[i .. $];
		if (exps.length == 1) {
			auto alit = cast(ir.ArrayLiteral) exps[0];
			if (alit !is null && alit.values.length == 0) {
				exps = [];
			}
		}
		foreach (ref aexp; exps) {
			extypePass(ctx, aexp, arr.base);
		}
		arguments[i] = buildInternalArrayLiteralSmart(arguments[0].location, asFunctionType.params[i], exps);
		arguments = arguments[0 .. i + 1];
		return;
	}
}

/**
 * Turns identifier postfixes into CreateDelegates,
 * and resolves property function calls in postfixes,
 * type safe varargs, and explicit constructor calls.
 */
void extypePostfixLeave(Context ctx, ref ir.Exp exp, ir.Postfix postfix,
                        ir.Exp parent)
{
	if (opOverloadRewriteIndex(ctx, postfix, exp)) {
		postfix = cast(ir.Postfix) exp;
		if (postfix !is null) {
			acceptExp(exp, ctx.extyper);
			return;
		}
	}

	if (postfix.arguments.length > 0) {
		ctx.enter(postfix);
		foreach (ref arg; postfix.arguments) {
			acceptExp(arg, ctx.extyper);
		}
		ctx.leave(postfix);
	}

	if (postfixIdentifier(ctx, exp, postfix, parent)) {
		return;
	}

	extypePostfixIndex(ctx, exp, postfix);

	if (replaceAAPostfixesIfNeeded(ctx, postfix, exp)) {
		return;
	}

	extypePostfixCall(ctx, exp, postfix);
}

void extypePostfixCall(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	if (postfix.op != ir.Postfix.Op.Call) {
		return;
	}

	auto type = getExpType(ctx.lp, postfix.child, ctx.current);
	bool thisCall;

	ir.CallableType asFunctionType;
	auto asFunctionSet = cast(ir.FunctionSetType) realType(type);
	ir.Function fn;

	auto eref = cast(ir.ExpReference) postfix.child;
	bool reeval = true;

	if (eref is null) {
		reeval = false;
		auto pchild = cast(ir.Postfix) postfix.child;
		if (pchild !is null) {
			eref = cast(ir.ExpReference) pchild.memberFunction;
		}
	}

	if (asFunctionSet !is null) {
		resolvePostfixOverload(ctx, postfix, eref, fn, asFunctionType, asFunctionSet, reeval);
	} else if (eref !is null) {
		fn = cast(ir.Function) eref.decl;
		asFunctionType = cast(ir.CallableType) realType(type);
		if (asFunctionType is null) {
			if (asFunctionType is null) {
				auto _class = cast(ir.Class) type;
				if (_class !is null) {
					// this(blah);
					fn = selectFunction(ctx.lp, ctx.current, _class.userConstructors, postfix.arguments, postfix.location);
					asFunctionType = fn.type;
					eref.decl = fn;
					thisCall = true;
				} else {
					throw makeBadCall(postfix, type);
				}
			}
		}
	}

	auto callable = cast(ir.CallableType) realType(getExpType(ctx.lp, postfix.child, ctx.current));
	if (callable is null) {
		throw makeError(postfix.location, "calling uncallable expression.");
	}

	if (asFunctionType is null) {
		return;
	}

	handleArgumentLabelsIfNeeded(ctx, postfix, fn, exp);

	// Not providing an argument to a homogenous variadic function.
	if (asFunctionType.homogenousVariadic && postfix.arguments.length + 1 == asFunctionType.params.length) {
		postfix.arguments ~= buildArrayLiteralSmart(postfix.location, asFunctionType.params[$-1], []);
	}

	rewriteVaStartAndEnd(ctx, fn, postfix, exp);
	rewriteVarargs(ctx, asFunctionType, postfix);

	appendDefaultArguments(ctx, postfix.location, postfix.arguments, fn);
	if (!(asFunctionType.hasVarArgs || asFunctionType.params.length > 0 && asFunctionType.homogenousVariadic) &&
	    postfix.arguments.length != asFunctionType.params.length) {
		throw makeWrongNumberOfArguments(postfix, postfix.arguments.length, asFunctionType.params.length);
	}
	assert(asFunctionType.params.length <= postfix.arguments.length);
	rewriteHomogenousVariadic(ctx, asFunctionType, postfix.arguments);
	foreach (i; 0 .. asFunctionType.params.length) {
		if (asFunctionType.isArgRef[i] || asFunctionType.isArgOut[i]) {
			if (!isLValue(postfix.arguments[i])) {
				throw makeNotLValue(postfix.arguments[i]);
			}
			if (asFunctionType.isArgRef[i] &&
			    postfix.argumentTags[i] != ir.Postfix.TagKind.Ref &&
			    !ctx.lp.settings.internalD) {
				throw makeNotTaggedRef(postfix.arguments[i], i);
			}
			if (asFunctionType.isArgOut[i] &&
			    postfix.argumentTags[i] != ir.Postfix.TagKind.Out &&
			    !ctx.lp.settings.internalD) {
				throw makeNotTaggedOut(postfix.arguments[i], i);
			}
		}
		extypePass(ctx, postfix.arguments[i], asFunctionType.params[i]);
	}

	if (thisCall) {
		// Explicit constructor call.
		auto tvar = getThisVar(postfix.location, ctx.lp, ctx.current);
		auto tref = buildExpReference(postfix.location, tvar, "this");
		postfix.arguments = buildCastToVoidPtr(postfix.location, tref) ~ postfix.arguments;
	}
}

/**
 * This function acts as a extyperExpReference function would do,
 * but it also takes a extra type context which is used for the
 * cases when looking up Member variables via Types.
 *
 * pkg.mod.Class.member = 4;
 *
 * Even though FunctionSets might need rewriting they are not rewritten
 * directly but instead this function is called after they have been
 * rewritten and the ExpReference has been resolved to a single Function.
 */
bool replaceExpReferenceIfNeeded(Context ctx, ir.Type referredType,
                                 ref ir.Exp exp, ir.ExpReference eRef)
{
	// For vtable and property.
	if (eRef.rawReference) {
		return false;
	}

	// Early out on static vars.
	// Or function sets.
	auto decl = eRef.decl;
	ir.Exp nestedLookup;
	final switch (decl.declKind) with (ir.Declaration.Kind) {
	case Function:
		auto asFn = cast(ir.Function)decl;
		if (isFunctionStatic(asFn)) {
			return false;
		}
		if (asFn.kind == ir.Function.Kind.Member) {
			auto ffn = getParentFunction(ctx.current);
			if (ffn !is null && ffn.nestStruct !is null && eRef.idents.length == 1) {
				nestedLookup = buildAccess(eRef.location, buildExpReference(eRef.location, ffn.nestedVariable), "this");
			}
		}
		break;
	case Variable:
		auto asVar = cast(ir.Variable)decl;
		auto ffn = getParentFunction(ctx.current);
		if (ffn !is null && ffn.nestStruct !is null && eRef.idents.length > 0) {
			auto access = buildAccess(eRef.location, buildExpReference(eRef.location, ffn.nestedVariable), "this");
			nestedLookup = buildAccess(eRef.location, access, eRef.idents[$-1]);
		}
		if (isVariableStatic(asVar)) {
			return false;
		}
		break;
	case FunctionParam:
		return false;
	case EnumDeclaration:
	case FunctionSet:
		return false;
	case Invalid:
		throw panic(decl, "invalid declKind");
	}

	auto thisVar = getThisVar(eRef.location, ctx.lp, ctx.current);
	assert(thisVar !is null);

	auto tr = cast(ir.TypeReference) thisVar.type;
	if (tr is null) {
		throw panic(eRef, "not TypeReference thisVar");
	}

	auto thisAgg = cast(ir.Aggregate) tr.type;
	if (thisAgg is null) {
		throw panic(eRef, "thisVar not aggregate");
	}

	/// Use this for if type not provided.
	if (referredType is null) {
		referredType = thisAgg;
	}

	auto expressionAgg = cast(ir.Aggregate) referredType;
	if (expressionAgg is null) {
		throw panic(eRef, "referredType not Aggregate");
	}

	string ident = eRef.idents[$-1];
	auto store = lookupInGivenScopeOnly(ctx.lp, expressionAgg.myScope, exp.location, ident);
	if (store !is null && store.node !is eRef.decl) {
		if (eRef.decl.nodeType !is ir.NodeType.FunctionParam) {
			bool found = false;
			foreach (fn; store.functions) {
				if (fn is eRef.decl) {
					found = true;
				}
			}
			if (!found) {
				throw makeNotMember(eRef, expressionAgg, ident);
			}
		}
	}

	auto thisClass = cast(ir.Class) thisAgg;
	auto expressionClass = cast(ir.Class) expressionAgg;
	if (thisClass !is null && expressionClass !is null) {
		if (!thisClass.isOrInheritsFrom(expressionClass)) {
			throw makeInvalidType(exp, expressionClass);
		}
	} else if (thisAgg !is expressionAgg) {
		throw makeInvalidThis(eRef, thisAgg, expressionAgg, ident);
	}

	ir.Exp thisRef = buildExpReference(eRef.location, thisVar, "this");
	if (thisClass !is expressionClass) {
		thisRef = buildCastSmart(eRef.location, expressionClass, thisRef);
	}

	if (eRef.decl.declKind == ir.Declaration.Kind.Function) {
		exp = buildCreateDelegate(eRef.location, nestedLookup !is null ? nestedLookup : thisRef, eRef);
	} else {
		if (nestedLookup !is null) {
			exp = nestedLookup; 
		} else {
			exp = buildAccess(eRef.location, thisRef, ident);
		}
	}

	return true;
}

/**
 * Turn identifier postfixes into <ExpReference>.ident.
 */
bool consumeIdentsIfScopesOrTypes(Context ctx, ref ir.Postfix[] postfixes,
                                  ref ir.Exp exp, ir.Exp parent)
{
	ir.Store store;
	ir.Type type;

	if (!getIfStoreOrTypeExp(postfixes[0].child, store, type)) {
		return false;
	}

	if (type !is null) {
		// Remove int.max etc.
		ir.Exp e = postfixes[0];
		if (typeLookup(ctx, e, type)) {
			if (postfixes.length > 1) {
				postfixes[1].child = e;
				postfixes = postfixes[1 .. $];
			} else {
				exp = e;
				postfixes = [];
			}
			return true;
		} else if (store is null) {
			return false;
		}
	}

	assert(store !is null);

	// Get a scope from said store.
	auto base = store.s;
	if (base is null) {
		auto named = cast(ir.Named) store.node;
		if (named !is null) {
			base = named.myScope;
		} else {
			return false;
		}
	}

	/* Get a declaration from the next identifier segment,
	 * replace with an expreference?
	 */
	string name;
	ir.Declaration decl;

	size_t i;
	for (i = 0; i < postfixes.length; ++i) {
		auto postfix = postfixes[i];
		if (postfix.identifier is null) {
			break;
		}

		name = postfix.identifier.value;
		store = lookupAsImportScope(ctx.lp, base, postfix.location, name);
		if (store is null) {
			throw makeFailedLookup(postfix.location, name);
		}

		ir.Exp toReplace;

		if (store.functions.length > 1) {
			toReplace = buildExpReference(postfix.location, buildSet(postfix.location, store.functions), name);
		}

		decl = cast(ir.Declaration) store.node;
		if (decl !is null && toReplace is null) {
			toReplace = buildExpReference(decl.location, decl, name);
		}

		auto named = cast(ir.Named) store.node;
		if (named !is null) {
			toReplace = buildStoreExp(named.location, store, name);
		}

		if (toReplace is null && store.s !is null) {
			base = store.s;
			continue;
		}

		if (toReplace !is null) {
			if (i+1 >= postfixes.length) {
				exp = toReplace;
				postfixes = [];
			} else {
				postfixes[i+1].child = toReplace;
				postfixes = postfixes[i+1 .. $];
			}
			return true;
		}
	}

	return false;
}

void extypePostfixIndex(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	if (postfix.op != ir.Postfix.Op.Index)
		return;

	auto type = getExpType(ctx.lp, postfix.child, ctx.current);
	if (type.nodeType == ir.NodeType.AAType) {
		auto aa = cast(ir.AAType)type;
		extypeAssign(ctx, postfix.arguments[0], aa.key);
	}
}

/**
 * This function will check for ufcs functions on a Identifier postfix,
 * it assumes we have already looked for a field and not found anything.
 *
 * Volt does not support property ufcs functions.
 */
void postfixIdentifierUFCS(Context ctx, ref ir.Exp exp,
                           ir.Postfix postfix, ir.Exp parent)
{
	assert(postfix.identifier !is null);

	auto store = lookup(ctx.lp, ctx.current, postfix.location, postfix.identifier.value);
	if (store is null || store.functions.length == 0) {
		throw makeNoFieldOrPropertyOrUFCS(postfix.location, postfix.identifier.value);
	}

	bool isProp;
	foreach (fn; store.functions) {
		if (isProp && !fn.type.isProperty) {
			throw makeError(postfix, "concidering both regular and property functions");
		}

		isProp = fn.type.isProperty;
	}

	if (isProp) {
		throw makeError(postfix, "concidering property functions for UFCS which is not supported");
	}

	// This is here to so that it errors
	ir.Postfix call = cast(ir.Postfix) parent;
	if (call is null || call.op != ir.Postfix.Op.Call) {
		throw makeNoFieldOrPropertyOrIsUFCSWithoutCall(postfix.location, postfix.identifier.value);
	}

	// Before we call selectFunction we need to extype the args.
	// @TODO This will be done twice, which is not the best of things.
	foreach (ref arg; call.arguments) {
		acceptExp(arg, ctx.extyper);
	}

	// Should we really call selectFunction here?
	auto arguments = postfix.child ~ call.arguments;
	auto fn = selectFunction(ctx.lp, ctx.current, store.functions, arguments, postfix.location);

	if (fn is null) {
		throw makeNoFieldOrPropertyOrUFCS(postfix.location, postfix.identifier.value);
	}

	call.arguments = arguments;
	call.child = buildExpReference(postfix.location, fn, fn.name);
	// We are done, make sure that the rebuilt call isn't messed with when
	// it get visited again by the extypePostfix function.

	auto theTag = ir.Postfix.TagKind.None;
	if (fn.type.isArgRef[0]) {
		theTag = ir.Postfix.TagKind.Ref;
	} else if (fn.type.isArgOut[0]) {
		theTag = ir.Postfix.TagKind.Out;
	}

	call.argumentTags = theTag ~ call.argumentTags;
}

bool builtInField(ir.Type type, string field)
{
	auto aa = cast(ir.AAType) type;
	if (aa !is null) {
		return field == "length" ||
			field == "get" ||
			field == "remove" ||
			field == "keys" ||
			field == "values";
	}
	auto array = cast(ir.ArrayType) type;
	auto sarray = cast(ir.StaticArrayType) type;
	return (sarray !is null || array !is null) && (field == "ptr" || field == "length");
}

/**
 * Rewrite exp if the store contains any property functions, works
 * for both PostfixExp and IdentifierExp.
 *
 * Child can be null.
 */
bool rewriteIfPropertyStore(ref ir.Exp exp, ir.Exp child, string name,
                            ir.Exp parent, ir.Store store)
{
	if (store.functions.length == 0) {
		return false;
	}

	ir.Function   getFn;
	ir.Function[] setFns;

	foreach (fn; store.functions) {
		if (!fn.type.isProperty) {
			continue;
		}

		if (fn.type.params.length > 1) {
			throw panic(fn, "property function with more than one argument.");
		} else if (fn.type.params.length == 1) {
			setFns ~= fn;
			continue;
		}

		// fn.params.length is 0

		if (getFn !is null) {
			throw makeError(exp.location, "multiple zero argument properties found.");
		}
		getFn = fn;
	}

	if (getFn is null && setFns.length == 0) {
		return false;
	}

	bool isAssign = parent !is null &&
	                parent.nodeType == ir.NodeType.BinOp &&
	                (cast(ir.BinOp) parent).op == ir.BinOp.Op.Assign;
	assert(!isAssign || (cast(ir.BinOp) parent).left is exp);

	if (!isAssign && getFn is null) {
		throw makeError(exp.location, "no zero argument property found.");
	}

	exp = buildProperty(exp.location, name, child, getFn, setFns);

	return true;
}

/**
 * Handling cases:
 *
 * inst.field               ( Any parent )
 * inst.inbuilt<field/prop> ( Any parent (no set inbuilt in Volt) )
 * inst.prop                ( Any parent )
 * inst.method              ( Any parent but Postfix.Op.Call )
 *
 * Check if there is a call on these cases.
 *
 * inst.inbuilt<function>() ( Postfix.Op.Call )
 * inst.method()            ( Postfix.Op.Call )
 * inst.ufcs()              ( Postfix.Op.Call )
 *
 * Error otherwise.
 */
bool postfixIdentifier(Context ctx, ref ir.Exp exp,
                       ir.Postfix postfix, ir.Exp parent)
{
	if (postfix.op != ir.Postfix.Op.Identifier) {
		return false;
	}

	string field = postfix.identifier.value;

	ir.Type oldType = getExpType(ctx.lp, postfix.child, ctx.current);
	ir.Type type = realType(oldType, false, false);
	assert(type !is null);
	assert(type.nodeType != ir.NodeType.FunctionSetType);
	if (builtInField(type, field)) {
		return false;
	}

	// If we are pointing to a pointer to a class.
	dereferenceInitialClass(postfix, oldType);

	// Get store for ident on type, do not look for ufcs functions.
	ir.Store store;
	auto _scope = getScopeFromType(type);
	if (_scope !is null) {
		store = lookupAsThisScope(ctx.lp, _scope, postfix.location, field);
	}

	if (store is null) {
		// Check if there is a UFCS function.
		// Note that Volt doesn't not support UFCS get/set properties
		// unlike D which does, this is because we are going to
		// remove properties in favor for C# properties.

		postfixIdentifierUFCS(ctx, exp, postfix, parent);

		// postfixIdentifierUFCS will error so if we get here all is good.
		return true;
	}

	// We are looking up via a instance error on static vars and types.
	// The two following cases are handled by the consumeIdents code:
	// pkg.mod.Class.staticVar
	// pkg.mod.Class.Enum
	//
	// But this is an error:
	// pkg.mode.Class instance;
	// instance.Enum
	// instance.staticVar
	//
	// @todo will the code be stupid and do this:
	// staticVar++ --> lowered to this.staticVar++ in a member function.
	//
	//if (<check>) {
	//	throw makeBadLookup();
	//}

	// Is the store a field on the object.
	auto store2 = lookupOnlyThisScopeAndClassParents(ctx.lp, _scope,
	                                                 postfix.location,
	                                                 field);
	auto var2 = cast(ir.Variable) store2.node;
	if (store2 !is null && var2 !is null &&
	    var2.storage == ir.Variable.Storage.Field) {
		return true;
	}

	// What if store (not store2) points at a field? Check and error.
	auto var = cast(ir.Variable) store.node;
	if (var !is null &&
	    var.storage == ir.Variable.Storage.Field) {
		throw makeAccessThroughWrongType(postfix.location, field);
	}

	// Check if the store is a property, for property _only_ members
	// on the class/struct.
	if (rewriteIfPropertyStore(exp, postfix.child, field, parent, store)) {
		return true;
	}

	// Check for member functions and static ufcs functions here. Static
	// ufcs functions can be overloaded with member functions in theory.
	// But for now if that is the case just error, because its just a too
	// deep a rabbit hole to go down into.
	auto parentPostfix = cast(ir.Postfix) parent;
	if (parentPostfix !is null &&
	    parentPostfix.op == ir.Postfix.Op.Call &&
	    store.functions.length > 0) {
		size_t members;
		foreach (func; store.functions) {
			if (func.kind == ir.Function.Kind.Member ||
			    func.kind == ir.Function.Kind.Destructor) {
				members++;
			}
		}

		// @TODO check this in postfixCall handling.
		if (members != store.functions.length) {
			if (members) {
				// @TODO Not a real error.
				throw makeError(postfix, "mixing static and member functions");
			} else {
				//throw makeCanNotLookupStaticVia
				throw makeError(postfix.location, "looking up '" ~ field ~ "' static function via instance.");
			}
		}

		auto fnSet = buildSet(postfix.location, store.functions);
		auto expRef = buildExpReference(postfix.location, fnSet, field);
		auto cdg = buildCreateDelegate(
			postfix.location, postfix.child, expRef);
		// @TODO Better way for super.'func'(); to work correctly.
		cdg.supressVtableLookup = postfix.hackSuperLookup;
		exp = cdg;
		return true;
	}

	// If parent isn't a call, make sure we only have a single member
	// function, that is a regular CreateDelegate expression.
	if (store.functions.length > 0 &&
	    (parentPostfix is null ||
	     parentPostfix.op != ir.Postfix.Op.Call)) {

		if (store.functions.length > 1) {
			//throw makeCanNotPickMemberfunction
			throw makeError(postfix.location, "cannot select member function '" ~ field ~ "'");
		} else if (store.functions[0].kind != ir.Function.Kind.Member) {
			//throw makeCanNotLookupStaticVia
			throw makeError(postfix.location, "looking up '" ~ field ~ "' static function via instance.");
		}

		auto fn = store.functions[0];
		exp = buildCreateDelegate(
			postfix.location,
			postfix.child,
			buildExpReference(postfix.location, fn, fn.name));
		return true;
	}

	throw makeNoFieldOrPropOrUFCS(postfix);
}

void extypePostfix(Context ctx, ref ir.Exp exp, ir.Postfix postfix, ir.Exp parent)
{
	auto allPostfixes = collectPostfixes(postfix);

	// Process first none postfix exp, often a IdentifierExp.
	// 'ident'.field.prop
	// 'typeid(int)'.mangledName
	// 'int'.max
	auto top = allPostfixes[0];
	if (top.child.nodeType == ir.NodeType.IdentifierExp) {
		auto ie = cast(ir.IdentifierExp) top.child;
		extypeIdentifierExp(ctx, top.child, ie, top);
	} else {
		acceptExp(allPostfixes[0].child, ctx.extyper);
	}

	// Now process the list of postfixes.
	while (allPostfixes.length > 0) {
		auto working = allPostfixes[0];

		if (working.op == ir.Postfix.Op.Identifier &&
		    consumeIdentsIfScopesOrTypes(ctx, allPostfixes, exp, parent)) {
			continue;
		}

		// popFront this way we advance and know if we have more.
		allPostfixes = allPostfixes[1 .. $];

		if (allPostfixes.length == 0) {
			// Exp points to the field in parent where the initial
			// postfix is stored.

			// The last element should be exp.
			assert(working is exp);

			extypePostfixLeave(ctx, exp, working, parent);
		} else {
			// Set the next in line as parent. This allows handling
			// of bar.ufcs(4, 5) and the like.
			auto tmp = allPostfixes[0];

			// Make sure we haven't rewritten this yet.
			assert(tmp.child is working);

			extypePostfixLeave(ctx, tmp.child, working, tmp);
		}
	}
	// The postfix parameter is stale now, don't touch it.
}

/**
 * Stops casting to an overloaded function name, casting from null, and wires
 * up some runtime magic needed for classes.
 */
void handleCastTo(Context ctx, ref ir.Exp exp, ir.Unary unary)
{
	assert(unary.type !is null);
	assert(unary.value !is null);

	auto type = realType(getExpType(ctx.lp, unary.value, ctx.current));
	if (type.nodeType == ir.NodeType.FunctionSetType) {
		auto fset = cast(ir.FunctionSetType) type;
		throw makeCannotDisambiguate(unary, fset.set.functions);
	}

	// Handling cast(Foo)null
	if (handleIfNull(ctx, unary.type, unary.value)) {
		exp = unary.value;
		return;
	}

	auto to = getClass(unary.type);
	auto from = getClass(type);

	if (to is null || from is null || to is from) {
		return;
	}

	auto fnref = buildExpReference(unary.location, ctx.lp.castFunc, "vrt_handle_cast");
	auto tid = buildTypeidSmart(unary.location, to);
	auto val = buildCastToVoidPtr(unary.location, unary.value);
	unary.value = buildCall(unary.location, fnref, [val, cast(ir.Exp)tid]);
}

/**
 * Type new expressions.
 */
void handleNew(Context ctx, ref ir.Exp exp, ir.Unary _unary)
{
	assert(_unary.type !is null);

	if (!_unary.hasArgumentList) {
		return;
	}

	auto at = cast(ir.AutoType) _unary.type;
	if (at !is null) {
		if (_unary.argumentList.length == 0) {
			throw makeExpected(_unary, "argument(s)");
		}
		_unary.type = copyTypeSmart(_unary.location, getExpType(ctx.lp, _unary.argumentList[0], ctx.current));
	}
	auto array = cast(ir.ArrayType) _unary.type;
	if (array !is null) {
		if (_unary.argumentList.length == 0) {
			throw makeExpected(_unary, "argument(s)");
		}
		bool isArraySize = isIntegral(getExpType(ctx.lp, _unary.argumentList[0], ctx.current));
		foreach (ref arg; _unary.argumentList) {
			auto type = getExpType(ctx.lp, arg, ctx.current);
			if (isIntegral(type)) {
				if (isArraySize) {
					// multi/one-dimensional array:
					//   new type[](1)
					//   new type[](1, 2, ...)
					continue;
				}
				throw makeExpected(arg, "array");
			} else if (isArraySize) {
				throw makeExpected(arg, "array size");
			}

			// it's a concatenation or copy:
			//   new type[](array1)
			//   new type[](array1, array2, ...)
			auto asArray = cast(ir.ArrayType) type;
			if (asArray is null) {
				throw makeExpected(arg, "array");
			}
			if (!typesEqual(asArray, array) &&
			    !isImplicitlyConvertable(asArray, array)) {
				if (typesEqual(asArray, array, true) &&
					(array.isConst || array.isImmutable ||
					array.base.isConst || array.base.isImmutable ||
					!mutableIndirection(array.base))) {
					// char[] buf;
					// auto str = new string(buf);
					continue;
				}
				throw makeBadImplicitCast(arg, asArray, array);
			}
		}
	}

	auto tr = cast(ir.TypeReference) _unary.type;
	if (tr is null) {
		return;
	}
	auto _struct = cast(ir.Struct) tr.type;
	if (_struct !is null) {
		assert(_unary.hasArgumentList);
		throw makeStructConstructorsUnsupported(_unary);
	}
	auto _class = cast(ir.Class) tr.type;
	if (_class is null) {
		return;
	}

	if (_class.isAbstract) {
		throw makeNewAbstract(_unary, _class);
	}

	// Needed because of userConstructors.
	ctx.lp.actualize(_class);

	auto fn = selectFunction(ctx.lp, ctx.current, _class.userConstructors, _unary.argumentList, _unary.location);
	appendDefaultArguments(ctx, _unary.location, _unary.argumentList, fn);

	ctx.lp.resolve(ctx.current, fn);
	if (_unary.argumentList.length > 0) {
		rewriteHomogenousVariadic(ctx, fn.type, _unary.argumentList);
	}

	for (size_t i = 0; i < _unary.argumentList.length; ++i) {
		extypeAssign(ctx, _unary.argumentList[i], fn.type.params[i]);
	}
}

/**
 * Lower. 'new foo[0 .. $]' expressions.
 */
void handleDup(Context ctx, ref ir.Exp exp, ir.Unary _unary)
{
	panicAssert(_unary, _unary.dupName !is null);
	panicAssert(_unary, _unary.dupBeginning !is null);
	panicAssert(_unary, _unary.dupEnd !is null);

	auto l = exp.location;
	if (!ctx.isFunction) {
		throw makeExpected(l, "function context");
	}

	auto sexp = buildStatementExp(l);
	auto type = getExpType(ctx.lp, _unary.value, ctx.current);
	auto asStatic = cast(ir.StaticArrayType)realType(type);
	if (asStatic !is null) {
		type = buildArrayTypeSmart(asStatic.location, asStatic.base);
	}

	auto rtype = realType(type);
	if (rtype.nodeType != ir.NodeType.AAType &&
	    rtype.nodeType != ir.NodeType.ArrayType) {
		throw makeCannotDup(l, rtype);
	}

	if (rtype.nodeType == ir.NodeType.AAType) {
		if (!_unary.fullShorthand) {
			// Actual indices were used, which makes no sense for AAs.
			throw makeExpected(l, format("new %s[..]", _unary.dupName));
		}
		exp = buildCall(l, buildExpReference(l, ctx.lp.aaDup, ctx.lp.aaDup.name), [_unary.value]);
		exp = buildCastSmart(l, type, exp);
		return;
	}

	auto length = buildSub(l, buildCastSmart(l, buildSizeT(l, ctx.lp), _unary.dupEnd),
		buildCastSmart(l, buildSizeT(l, ctx.lp), _unary.dupBeginning));
	auto newExp = buildNewSmart(l, type, length);
	auto var = buildVariableAnonSmart(l, ctx.current, sexp, type, newExp);
	auto evar = buildExpReference(l, var, var.name);
	auto sliceL = buildSlice(l, evar, copyExp(_unary.dupBeginning), copyExp(_unary.dupEnd));
	auto sliceR = buildSlice(l, copyExp(_unary.value), copyExp(_unary.dupBeginning), copyExp(_unary.dupEnd));

	sexp.exp = buildAssign(l, sliceL, sliceR);
	exp = sexp;
}

void extypeUnary(Context ctx, ref ir.Exp exp, ir.Unary _unary)
{
	switch (_unary.op) with (ir.Unary.Op) {
	case Cast:
		return handleCastTo(ctx, exp, _unary);
	case New:
		return handleNew(ctx, exp, _unary);
	case Dup:
		return handleDup(ctx, exp, _unary);
	default:
	}
}

/**
 * Everyone's favourite: integer promotion! :D!
 * In general, converts to the largest type needed in a binary expression.
 */
void extypeBinOp(Context ctx, ir.BinOp bin, ir.PrimitiveType lprim, ir.PrimitiveType rprim)
{
	auto leftsz = size(lprim.type);
	auto rightsz = size(rprim.type);

	if (isIntegral(lprim) && isIntegral(rprim)) {
		bool leftUnsigned = isUnsigned(lprim.type);
		bool rightUnsigned = isUnsigned(rprim.type);
		if (leftUnsigned != rightUnsigned) {
			// Cast constants.
			if (leftUnsigned) {
				if (fitsInPrimitive(lprim, bin.right)) {
					bin.right = buildCastSmart(lprim, bin.right);
					rightUnsigned = true;
					rightsz = leftsz;
				}
			} else {
				if (fitsInPrimitive(rprim, bin.left)) {
					bin.left = buildCastSmart(rprim, bin.left);
					leftUnsigned = true;
					leftsz = rightsz;
				}
			}
			if (leftUnsigned != rightUnsigned) {
				throw makeMixedSignedness(bin.location);
			}
		}
	}

	if (bin.op != ir.BinOp.Op.Assign &&
	    bin.op != ir.BinOp.Op.Is &&
	    bin.op != ir.BinOp.Op.NotIs &&
	    bin.op != ir.BinOp.Op.Equal &&
	    bin.op != ir.BinOp.Op.NotEqual) {
		if (isBool(lprim)) {
			auto i = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
			lprim = i;
			bin.left = buildCastSmart(i, bin.left);
		}
		if (isBool(rprim)) {
			auto i = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
			rprim = i;
			bin.right = buildCastSmart(i, bin.right);
		}
	}

	auto intsz = size(ir.PrimitiveType.Kind.Int);
	size_t largestsz;
	ir.Type largestType;

	if ((isFloatingPoint(lprim) && isFloatingPoint(rprim)) ||
	    (isIntegral(lprim) && isIntegral(rprim))) {
		if (leftsz > rightsz) {
			largestsz = leftsz;
			largestType = lprim;
		} else {
			largestsz = rightsz;
			largestType = rprim;
		}

		if (bin.op != ir.BinOp.Op.Assign && intsz > largestsz && isIntegral(lprim)) {
			largestsz = intsz;
			largestType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
		}

		if (leftsz < largestsz) {
			bin.left = buildCastSmart(largestType, bin.left);
		}

		if (rightsz < largestsz) {
			bin.right = buildCastSmart(largestType, bin.right);
		}

		return;
	}

	if (isFloatingPoint(lprim) && isIntegral(rprim)) {
		bin.right = buildCastSmart(lprim, bin.right);
	} else {
		bin.left = buildCastSmart(rprim, bin.left);
	}
}

/**
 * If the given binop is working on an aggregate
 * that overloads that operator, rewrite a call to that overload.
 */
bool opOverloadRewrite(Context ctx, ir.BinOp binop, ref ir.Exp exp)
{
	auto l = exp.location;
	auto _agg = opOverloadableOrNull(getExpType(ctx.lp, binop.left, ctx.current));
	if (_agg is null) {
		return false;
	}
	bool neg = binop.op == ir.BinOp.Op.NotEqual;
	string overfn = overloadName(neg ? ir.BinOp.Op.Equal : binop.op);
	if (overfn.length == 0) {
		return false;
	}
	auto store = lookupAsThisScope(ctx.lp, _agg.myScope, l, overfn);
	if (store is null || store.functions.length == 0) {
		throw makeAggregateDoesNotDefineOverload(exp.location, _agg, overfn);
	}
	auto fn = selectFunction(ctx.lp, ctx.current, store.functions, [binop.right], l);
	assert(fn !is null);
	exp = buildCall(l, buildCreateDelegate(l, binop.left, buildExpReference(l, fn, overfn)), [binop.right]);
	if (neg) {
		exp = buildNot(l, exp);
	}
	return true;
}

/**
 * If this postfix operates on an aggregate with an index
 * operator overload, rewrite it.
 */
bool opOverloadRewriteIndex(Context ctx, ir.Postfix pfix, ref ir.Exp exp)
{
	if (pfix.op != ir.Postfix.Op.Index) {
		return false;
	}
	auto type = getExpType(ctx.lp, pfix.child, ctx.current);
	auto _agg = opOverloadableOrNull(type);
	if (_agg is null) {
		return false;
	}
	auto name = overloadIndexName();
	auto store = lookupAsThisScope(ctx.lp, _agg.myScope, exp.location, name);
	if (store is null || store.functions.length == 0) {
		throw makeAggregateDoesNotDefineOverload(exp.location, _agg, name);
	}
	assert(pfix.arguments.length > 0 && pfix.arguments[0] !is null);
	auto fn = selectFunction(ctx.lp, ctx.current, store.functions, [pfix.arguments[0]], exp.location);
	assert(fn !is null);
	exp = buildCall(exp.location, buildCreateDelegate(exp.location, pfix.child, buildExpReference(exp.location, fn, name)), [pfix.arguments[0]]);
	return true;
}

bool extypeBinOpPropertyAssign(Context ctx, ir.BinOp binop, ref ir.Exp exp)
{
	if (binop.op != ir.BinOp.Op.Assign) {
		return false;
	}
	auto p = cast(ir.PropertyExp) binop.left;
	if (p is null) {
		return false;
	}

	auto args = [binop.right];
	auto fn = selectFunction(
		ctx.lp, ctx.current,
		p.setFns, args,
		binop.location, DoNotThrow);

	auto name = p.identifier.value;
	auto expRef = buildExpReference(binop.location, fn, name);

	if (p.child is null) {
		exp = buildCall(binop.location, expRef, args);
	} else {
		exp = buildMemberCall(binop.location,
		                      p.child,
		                      expRef, name, args);
	}

	return true;
}

/**
 * Handles logical operators (making a && b result in a bool),
 * binary of storage types, otherwise forwards to assign or primitive
 * specific functions.
 */
void extypeBinOp(Context ctx, ir.BinOp binop, ref ir.Exp exp)
{
	if (extypeBinOpPropertyAssign(ctx, binop, exp)) {
		return;
	}

	auto lraw = getExpType(ctx.lp, binop.left, ctx.current);
	auto rraw = getExpType(ctx.lp, binop.right, ctx.current);
	auto ltype = realType(removeRefAndOut(lraw));
	auto rtype = realType(removeRefAndOut(rraw));


	if (handleIfNull(ctx, rtype, binop.left)) return;
	if (handleIfNull(ctx, ltype, binop.right)) return;

	if (opOverloadRewrite(ctx, binop, exp)) {
		return;
	}

	auto lclass = cast(ir.Class)ltype;
	auto rclass = cast(ir.Class)rtype;
	if (lclass !is null && rclass !is null && !typesEqual(lclass, rclass)) {
		auto common = commonParent(lclass, rclass);
		if (lclass !is common) {
			binop.left = buildCastSmart(exp.location, common, binop.left);
		}
		if (rclass !is common) {
			binop.right = buildCastSmart(exp.location, common, binop.right);
		}
	}

	// key in aa => some_vrt_call(aa, key)
	if (binop.op == ir.BinOp.Op.In) {
		auto asAA = cast(ir.AAType) rtype;
		if (asAA is null) {
			throw makeExpected(binop.right.location, "associative array");
		}
		extypeAssign(ctx, binop.left, asAA.key);
		ir.Exp rtFn, key;
		auto l = binop.location;
		if (isArray(ltype)) {
			rtFn = buildExpReference(l, ctx.lp.aaInArray, ctx.lp.aaInArray.name);
			key = buildCast(l, buildArrayType(l, buildVoid(l)), copyExp(binop.left));
		} else {
			rtFn = buildExpReference(l, ctx.lp.aaInPrimitive, ctx.lp.aaInPrimitive.name);
			key = buildCast(l, buildUlong(l), copyExp(binop.left));
		}
		assert(rtFn !is null);
		assert(key !is null);

		auto args = new ir.Exp[](2);
		args[0] = copyExp(binop.right);
		args[1] = key;

		auto retptr = buildPtrSmart(l, asAA.value);
		auto call = buildCall(l, rtFn, args);
		exp = buildCast(l, retptr, call);
		return;
	}

	switch(binop.op) with(ir.BinOp.Op) {
	case AddAssign, SubAssign, MulAssign, DivAssign, ModAssign, AndAssign,
	     OrAssign, XorAssign, CatAssign, LSAssign, SRSAssign, RSAssign, PowAssign, Assign:
		// TODO this needs to be changed if there is operator overloading
		if (!isAssignable(binop.left)) {
			throw makeExpected(binop.left.location, "lvalue");
		}
		auto asPostfix = cast(ir.Postfix)binop.left;
		if (asPostfix !is null) {
			auto postfixLeft = getExpType(ctx.lp, asPostfix.child, ctx.current);
			if (postfixLeft !is null &&
			    postfixLeft.nodeType == ir.NodeType.AAType &&
			    asPostfix.op == ir.Postfix.Op.Index) {
				auto aa = cast(ir.AAType)postfixLeft;

				extypeAssign(ctx, binop.right, aa.value);
			}
		}
		break;
	default: break;
	}

	bool assigningOutsideFunction;
	if (auto eref = cast(ir.ExpReference)binop.left) {
		auto var = cast(ir.Variable) eref.decl;
		assigningOutsideFunction = var !is null && var.storage != ir.Variable.Storage.Function;
	}
	if (assigningOutsideFunction && rtype.isScope && mutableIndirection(ltype) && isAssign(exp) && !binop.isInternalNestedAssign) {
		throw makeNoEscapeScope(exp.location);
	}


	if (binop.op == ir.BinOp.Op.Assign) {
		if (effectivelyConst(ltype)) {
			throw makeCannotModify(binop, ltype);
		}

		auto postfixl = cast(ir.Postfix)binop.left;
		auto postfixr = cast(ir.Postfix)binop.right;
		bool copying = postfixl !is null && postfixr !is null &&
			postfixl.op == ir.Postfix.Op.Slice &&
			postfixr.op == ir.Postfix.Op.Slice;
		extypeAssign(ctx, binop.right, ltype, copying);

		return;
	}

	if (binop.op == ir.BinOp.Op.AndAnd || binop.op == ir.BinOp.Op.OrOr) {
		auto boolType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		if (!typesEqual(ltype, boolType)) {
			binop.left = buildCastSmart(boolType, binop.left);
		}
		if (!typesEqual(rtype, boolType)) {
			binop.right = buildCastSmart(boolType, binop.right);
		}
		return;
	}

	auto larray = cast(ir.ArrayType)ltype;
	auto rarray = cast(ir.ArrayType)rtype;
	if ((binop.op == ir.BinOp.Op.Cat ||
	     binop.op == ir.BinOp.Op.CatAssign) &&
	    (larray !is null || rarray !is null)) {
		if (binop.op == ir.BinOp.Op.CatAssign &&
		    effectivelyConst(ltype)) {
			throw makeCannotModify(binop, ltype);
		}
		bool swapped = binop.op != ir.BinOp.Op.CatAssign && larray is null;
		if (swapped) {
			extypeCat(ctx, binop.right, binop.left, rarray, ltype);
		} else {
			extypeCat(ctx, binop.left, binop.right, larray, rtype);
		}
		return;
	}

	if (ltype.nodeType == ir.NodeType.PrimitiveType &&
	    rtype.nodeType == ir.NodeType.PrimitiveType) {
		auto lprim = cast(ir.PrimitiveType) ltype;
		auto rprim = cast(ir.PrimitiveType) rtype;
		assert(lprim !is null && rprim !is null);
		extypeBinOp(ctx, binop, lprim, rprim);
	}
}

/**
 * Ensure concatentation is sound.
 */
void extypeCat(Context ctx, ref ir.Exp lexp, ref ir.Exp rexp,
               ir.ArrayType left, ir.Type right)
{
	if (typesEqual(left, right) ||
	    typesEqual(right, left.base)) {
		return;
	}

	void getClass(ir.Type t, ref int depth, ref ir.Class _class)
	{
		depth = 0;
		_class = cast(ir.Class)realType(t);
		auto array = cast(ir.ArrayType)realType(t);
		while (array !is null && _class is null) {
			depth++;
			_class = cast(ir.Class)realType(array.base);
			array = cast(ir.ArrayType)realType(array.base);
		}
	}

	ir.Type buildDeepArraySmart(Location location, int depth, ir.Type base)
	{
		ir.ArrayType array = new ir.ArrayType();
		array.location = location;
		auto firstArray = array;
		for (size_t i = 1; i < cast(size_t) depth; ++i) {
			array.base = new ir.ArrayType();
			array.base.location = location;
			array = cast(ir.ArrayType)array.base;
		}
		array.base = copyTypeSmart(location, base);
		return firstArray;
	}

	ir.Class lclass, rclass;
	int ldepth, rdepth;
	getClass(left, ldepth, lclass);
	getClass(right, rdepth, rclass);
	if (lclass !is null && rclass !is null) {
		auto _class = commonParent(lclass, rclass);
		if (ldepth >= 1 && ldepth == rdepth) {
			auto l = lexp.location;
			if (lclass !is _class) {
				lexp = buildCastSmart(buildDeepArraySmart(l, ldepth, _class), lexp);
			}
			if (rclass !is _class) {
				rexp = buildCastSmart(buildDeepArraySmart(l, rdepth, _class), rexp);
			}
			return;
		} else if (ldepth == 0 || rdepth == 0) {
			if (ldepth == 0 && lclass !is _class) {
				lexp = buildCastSmart(_class, lexp);
				return;
			} else if (rdepth == 0 && rclass !is _class) {
				rexp = buildCastSmart(_class, rexp);
				return;
			}
		}
	}

	auto rarray = cast(ir.ArrayType) realType(right);
	if (rarray !is null && isImplicitlyConvertable(rarray.base, left.base)) {
		return;
	}

	extypeAssign(ctx, rexp, rarray is null ? left.base : left);
	rexp = buildCastSmart(left.base, rexp);
}

void extypeTernary(Context ctx, ir.Ternary ternary)
{
	auto trueType = realType(getExpType(ctx.lp, ternary.ifTrue, ctx.current));
	auto falseType = realType(getExpType(ctx.lp, ternary.ifFalse, ctx.current));

	auto aClass = cast(ir.Class) trueType;
	auto bClass = cast(ir.Class) falseType;
	if (aClass !is null && bClass !is null) {
		auto common = commonParent(aClass, bClass);
		extypeAssign(ctx, ternary.ifTrue, common);
		extypeAssign(ctx, ternary.ifFalse, common);
	} else {
		// matchLevel lives in volt.semantic.overload.
		int trueMatchLevel = trueType.nodeType == ir.NodeType.NullType ? 0 : matchLevel(false, trueType, falseType);
		int falseMatchLevel = falseType.nodeType == ir.NodeType.NullType ? 0 : matchLevel(false, falseType, trueType);
		ir.Exp baseExp = trueMatchLevel > falseMatchLevel ? ternary.ifTrue : ternary.ifFalse;
		auto baseType = getExpType(ctx.lp, baseExp, ctx.current);
		assert(baseType.nodeType != ir.NodeType.NullType);
		if (trueMatchLevel > falseMatchLevel) {
			extypeAssign(ctx, ternary.ifFalse, baseType);
		} else {
			extypeAssign(ctx, ternary.ifTrue, baseType);
		}
	}

	auto condType = getExpType(ctx.lp, ternary.condition, ctx.current);
	if (!isBool(condType)) {
		ternary.condition = buildCastToBool(ternary.condition.location, ternary.condition);
	}
}

void extypeStructLiteral(Context ctx, ir.StructLiteral sl)
{
	if (sl.type is null) {
		throw makeError(sl, "can deduce type of struct literal");
	}

	auto asStruct = cast(ir.Struct) realType(sl.type);
	assert(asStruct !is null);
	ir.Type[] types = getStructFieldTypes(asStruct);

	// @TODO fill out with T.init
	if (types.length != sl.exps.length) {
		throw makeError(sl, "wrong number of arguments to struct literal");
	}

	foreach (i, ref sexp; sl.exps) {

		if (ctx.isFunction) {
			extypeAssign(ctx, sexp, types[i]);
			continue;
		}

		if (isBackendConstant(sexp)) {
			extypeAssign(ctx, sexp, types[i]);
			continue;
		}

		auto n = evaluateOrNull(ctx.lp, ctx.current, sexp);
		if (n is null) {
			throw makeError(sexp.location, "non-constant expression in global struct literal.");
		}

		sexp = n;
		extypeAssign(ctx, sexp, types[i]);
	}
}

/// Replace TypeOf with its expression's type, if needed.
void replaceTypeOfIfNeeded(Context ctx, ref ir.Type type)
{
	auto asTypeOf = cast(ir.TypeOf) realType(type);
	if (asTypeOf is null) {
		assert(type.nodeType != ir.NodeType.TypeOf);
		return;
	}

	type = copyTypeSmart(asTypeOf.location, getExpType(ctx.lp, asTypeOf.exp, ctx.current));
}

/**
 * Ensure that a thrown type inherits from Throwable.
 */
void extypeThrow(Context ctx, ir.ThrowStatement t)
{
	auto throwable = cast(ir.Class) retrieveTypeFromObject(ctx.lp, t.location, "Throwable");
	assert(throwable !is null);

	auto type = getExpType(ctx.lp, t.exp, ctx.current);
	auto asClass = cast(ir.Class) type;
	if (asClass is null) {
		throw makeThrowOnlyThrowable(t.exp, type);
	}

	if (!asClass.isOrInheritsFrom(throwable)) {
		throw makeThrowNoInherits(t.exp, asClass);
	}

	if (asClass !is throwable) {
		t.exp = buildCastSmart(t.exp.location, throwable, t.exp);
	}
}

/**
 * Correct this references in nested functions.
 */
void handleNestedThis(ir.Function fn)
{
	auto np = fn.nestedVariable;
	auto ns = fn.nestStruct;
	if (np is null || ns is null) {
		return;
	}
	size_t index;
	for (index = 0; index < fn._body.statements.length; ++index) {
		if (fn._body.statements[index] is np) {
			break;
		}
	}
	if (++index >= fn._body.statements.length) {
		return;
	}
	if (fn.thisHiddenParameter !is null) {
		auto l = buildAccess(fn.location, buildExpReference(np.location, np, np.name), "this");
		auto tv = fn.thisHiddenParameter;
		auto r = buildExpReference(fn.location, tv, tv.name);
		r.doNotRewriteAsNestedLookup = true;
		ir.Node n = buildExpStat(l.location, buildAssign(l.location, l, r));
		fn._body.statements.insertInPlace(index, n);
	}
}

/**
 * Given a nested function fn, add its parameters to the nested
 * struct and insert statements after the nested declaration.
 */
void handleNestedParams(Context ctx, ir.Function fn)
{
	auto np = fn.nestedVariable;
	auto ns = fn.nestStruct;
	if (np is null || ns is null) {
		return;
	}

	// This is needed for the parent function.
	size_t index;
	for (index = 0; index < fn._body.statements.length; ++index) {
		if (fn._body.statements[index] is np) {
			break;
		}
	}
	++index;

	if (index > fn._body.statements.length) {
		index = 0;  // We didn't find a usage, so put it at the start.
	}

	foreach (i, param; fn.params) {
		if (!param.hasBeenNested) {
			param.hasBeenNested = true;

			auto type = param.type;
			bool refParam = fn.type.isArgRef[i] || fn.type.isArgOut[i];
			if (refParam) {
				type = buildPtrSmart(param.location, param.type);
			}
			auto name = param.name != "" ? param.name : "__anonparam_" ~ toString(index);
			auto var = buildVariableSmart(param.location, type, ir.Variable.Storage.Field, name);
			addVarToStructSmart(ns, var);
			// Insert an assignment of the param to the nest struct.

			auto l = buildAccess(param.location, buildExpReference(np.location, np, np.name), name);
			auto r = buildExpReference(param.location, param, name);
			r.doNotRewriteAsNestedLookup = true;
			ir.BinOp bop;
			if (!refParam) {
				bop = buildAssign(l.location, l, r);
			} else {
				bop = buildAssign(l.location, l, buildAddrOf(r.location, r));
			}
			bop.isInternalNestedAssign = true;
			ir.Node n = buildExpStat(l.location, bop);
			if (isNested(fn)) {
				// Nested function.
				fn._body.statements = n ~ fn._body.statements;
			} else {
				// Parent function with nested children.
				fn._body.statements.insertInPlace(index++, n);
			}
		}
	}
}

// Moved here for now.
struct ArrayCase
{
	ir.Exp originalExp;
	ir.SwitchCase _case;
	ir.IfStatement lastIf;
}

/**
 * Ensure that a given switch statement is semantically sound.
 * Errors on bad final switches (doesn't cover all enum members, not on an enum at all),
 * and checks for doubled up cases.
 *
 * oldCondition is the switches condition prior to the extyper being run on it.
 * It's a bit of a hack, but we need the unprocessed enum to evaluate final switches.
 */
void verifySwitchStatement(Context ctx, ir.SwitchStatement ss)
{
	auto conditionType = realType(getExpType(ctx.lp, ss.condition, ctx.current), false, true);
	auto originalCondition = ss.condition;
	if (isArray(conditionType)) {
		auto l = ss.location;
		auto asArray = cast(ir.ArrayType) conditionType;
		assert(asArray !is null);
		ir.Exp ptr = buildCastSmart(buildVoidPtr(l), buildAccess(l, copyExp(ss.condition), "ptr"));
		ir.Exp length = buildBinOp(l, ir.BinOp.Op.Mul, buildAccess(l, copyExp(ss.condition), "length"),
				buildAccess(l, buildTypeidSmart(l, asArray.base), "size"));
		ss.condition = buildCall(ss.condition.location, ctx.lp.hashFunc, [ptr, length]);
		conditionType = buildUint(ss.condition.location);
	}
	ArrayCase[uint] arrayCases;
	size_t[] toRemove;  // Indices of cases that have been folded into a collision case.

	int defaultCount;
	foreach (i, _case; ss.cases) {
		void replaceWithHashIfNeeded(ref ir.Exp exp) 
		{
			if (exp is null) {
				return;
			}

			auto etype = getExpType(ctx.lp, exp, ctx.current);
			if (!isArray(etype)) {
				return;
			}

			uint h;
			auto constant = cast(ir.Constant) exp;
			if (constant !is null) {
				assert(isString(etype));
				assert(constant._string[0] == '\"');
				assert(constant._string[$-1] == '\"');
				auto str = constant._string[1..$-1];
				h = hash(cast(ubyte[]) str);
			} else {
				auto alit = cast(ir.ArrayLiteral) exp;
				assert(alit !is null);
				auto atype = cast(ir.ArrayType) etype;
				assert(atype !is null);
				uint[] intArrayData;
				ulong[] longArrayData;
				size_t sz;
				void addExp(ir.Exp e)
				{
					auto constant = cast(ir.Constant) e;
					if (constant !is null) {
						if (sz == 0) {
							sz = size(ctx.lp, constant.type);
							assert(sz > 0);
						}
						switch (sz) {
						case 8:
							longArrayData ~= constant.u._ulong;
							break;
						default:
							intArrayData ~= constant.u._uint;
							break;
						}
						return;
					}
					auto cexp = cast(ir.Unary) e;
					if (cexp !is null) {
						assert(cexp.op == ir.Unary.Op.Cast);
						assert(sz == 0);
						sz = size(ctx.lp, cexp.type);
						assert(sz == 8);
						addExp(cexp.value);
						return;
					}
					auto type = getExpType(ctx.lp, exp, ctx.current);
					throw makeSwitchBadType(ss, type);
				}
				foreach (e; alit.values) {
					addExp(e);
				}
				if (sz == 8) {
					h = hash(cast(ubyte[]) longArrayData);
				} else {
					h = hash(cast(ubyte[]) intArrayData);
				}
			}
			if (auto p = h in arrayCases) {
				auto aStatements = _case.statements.statements;
				auto bStatements = p._case.statements.statements;
				auto c = p._case.statements.myScope;
				auto aBlock = buildBlockStat(exp.location, p._case.statements, c, aStatements);
				auto bBlock = buildBlockStat(exp.location, p._case.statements, c, bStatements);
				p._case.statements.statements = null;
				auto cmp = buildBinOp(exp.location, ir.BinOp.Op.Equal, copyExp(exp), copyExp(originalCondition));
				auto ifs = buildIfStat(exp.location, p._case.statements, cmp, aBlock, bBlock);
				p._case.statements.statements[0] = ifs;
				if (p.lastIf !is null) {
					p.lastIf.thenState.myScope.parent = ifs.elseState.myScope;
					p.lastIf.elseState.myScope.parent = ifs.elseState.myScope;
				}
				p.lastIf = ifs;
				toRemove ~= i;
			} else {
				ArrayCase ac = {exp, _case, null};
				arrayCases[h] = ac;
			}
			exp = buildConstantUint(exp.location, h);
		}

		if (_case.isDefault) {
			defaultCount++;
		}
		if (_case.firstExp !is null) {
			replaceWithHashIfNeeded(_case.firstExp);
			extypeAssign(ctx, _case.firstExp, conditionType);
		}
		if (_case.secondExp !is null) {
			replaceWithHashIfNeeded(_case.secondExp);
			extypeAssign(ctx, _case.secondExp, conditionType);
		}
		foreach (ref exp; _case.exps) {
			replaceWithHashIfNeeded(exp);
			extypeAssign(ctx, exp, conditionType);
		}
	}

	if (!ss.isFinal && defaultCount == 0) {
		throw makeNoDefaultCase(ss.location);
	}
	if (ss.isFinal && defaultCount > 0) {
		throw makeFinalSwitchWithDefault(ss.location);
	}
	if (defaultCount > 1) {
		throw makeMultipleDefaults(ss.location);
	}

	for (int i = cast(int) toRemove.length - 1; i >= 0; i--) {
		ss.cases = ss.cases[0 .. i] ~ ss.cases[i .. $];
	}

	auto asEnum = cast(ir.Enum) conditionType;
	if (asEnum is null && ss.isFinal) {
		asEnum = cast(ir.Enum)realType(getExpType(ctx.lp, ss.condition, ctx.current), false, true);
		if (asEnum is null) {
			throw makeExpected(ss, "enum type for final switch");
		}
	}
	size_t caseCount;
	foreach (_case; ss.cases) {
		if (_case.firstExp !is null) {
			caseCount++;
		}
		if (_case.secondExp !is null) {
			caseCount++;
		}
		caseCount += _case.exps.length;
	}

	if (ss.isFinal && caseCount != asEnum.members.length) {
		throw makeFinalSwitchBadCoverage(ss);
	}
}

/**
 * Check a given Aggregate's anonymous structs/unions
 * (if any) for name collisions.
 */
void checkAnonymousVariables(Context ctx, ir.Aggregate agg)
{
	if (agg.anonymousAggregates.length == 0) {
		return;
	}
	bool[string] names;
	foreach (anonAgg; agg.anonymousAggregates) foreach (n; anonAgg.members.nodes) {
		auto var = cast(ir.Variable) n;
		auto fn = cast(ir.Function) n;
		string name;
		if (var !is null) {
			name = var.name;
		} else if (fn !is null) {
			name = fn.name;
		} else {
			continue;
		}
		if ((name in names) !is null) {
			throw makeAnonymousAggregateRedefines(anonAgg, name);
		}
		auto store = lookupAsThisScope(ctx.lp, agg.myScope, agg.location, name);
		if (store !is null) {
			throw makeAnonymousAggregateRedefines(anonAgg, name);
		}
	}
}

/// Turn a runtime assert into an if and a throw.
ir.Node transformRuntimeAssert(Context ctx, ir.AssertStatement as)
{
	if (as.isStatic) {
		throw panic(as.location, "expected runtime assert");
	}
	auto l = as.location;
	ir.Exp message = as.message;
	if (message is null) {
		message = buildConstantString(l, "assertion failure");
	}
	assert(message !is null);
	auto exception = buildNew(l, ctx.lp.assertErrorClass, "AssertError", message);
	auto theThrow  = buildThrowStatement(l, exception);
	auto thenBlock = buildBlockStat(l, null, ctx.current, theThrow);
	auto ifS = buildIfStat(l, buildNot(l, as.condition), thenBlock);
	return ifS;
}

/**
 * Process the types and expressions on a foreach.
 * Foreaches become for loops before the backend sees them,
 * but they still need to be made valid by the extyper.
 */
void extypeForeach(Context ctx, ir.ForeachStatement fes)
{
	void fillBlankVariable(size_t i, ir.Type t)
	{
		auto atype = cast(ir.AutoType) fes.itervars[i].type;
		if (atype is null || atype.explicitType !is null) {
			return;
		}
		fes.itervars[i].type = copyTypeSmart(fes.itervars[i].location, t);
	}

	foreach (var; fes.itervars) {
		auto at = cast(ir.AutoType) var.type;
		if (at !is null && at.isForeachRef) {
			fes.refvars ~= true;
			var.type = at.explicitType;
		} else {
			fes.refvars ~= false;
		}
	}

	if (fes.aggregate is null) {
		auto a = cast(ir.PrimitiveType) getExpType(ctx.lp, fes.beginIntegerRange, ctx.current);
		auto b = cast(ir.PrimitiveType) getExpType(ctx.lp, fes.endIntegerRange, ctx.current);
		if (a is null || b is null) {
			throw makeExpected(fes.beginIntegerRange.location, "primitive types");
		}
		if (!typesEqual(a, b)) {
			auto asz = size(ctx.lp, a);
			auto bsz = size(ctx.lp, b);
			if (bsz > asz) {
				extypeAssignPrimitiveType(ctx, fes.beginIntegerRange, b);
				fillBlankVariable(0, b);
			} else if (asz > bsz) {
				extypeAssignPrimitiveType(ctx, fes.endIntegerRange, a);
				fillBlankVariable(0, a);
			} else {
				auto ac = evaluateOrNull(ctx.lp, ctx.current, fes.beginIntegerRange);
				auto bc = evaluateOrNull(ctx.lp, ctx.current, fes.endIntegerRange);
				if (ac !is null) {
					extypeAssignPrimitiveType(ctx, fes.beginIntegerRange, b);
					fillBlankVariable(0, b);
				} else if (bc !is null) {
					extypeAssignPrimitiveType(ctx, fes.endIntegerRange, a);
					fillBlankVariable(0, a);
				}
			}
		}
		fillBlankVariable(0, a);
		return;
	}

	acceptExp(fes.aggregate, ctx.extyper);

	auto aggType = realType(getExpType(ctx.lp, fes.aggregate, ctx.current), true, true);

	ir.Type key, value;
	switch (aggType.nodeType) {
	case ir.NodeType.ArrayType:
		auto asArray = cast(ir.ArrayType) aggType;
		value = copyTypeSmart(fes.aggregate.location, asArray.base);
		key = buildSizeT(fes.location, ctx.lp);
		break;
	case ir.NodeType.StaticArrayType:
		auto asArray = cast(ir.StaticArrayType) aggType;
		value = copyTypeSmart(fes.aggregate.location, asArray.base);
		key = buildSizeT(fes.location, ctx.lp);
		break;
	case ir.NodeType.AAType:
		auto asArray = cast(ir.AAType) aggType;
		value = copyTypeSmart(fes.aggregate.location, asArray.value);
		key = copyTypeSmart(fes.aggregate.location, asArray.key);
		break;
	default:
		throw makeExpected(fes.aggregate.location, "array, static array, or associative array.");
	}


	if (fes.itervars.length == 2) {
		fillBlankVariable(0, key);
		fillBlankVariable(1, value);
	} else if (fes.itervars.length == 1) {
		fillBlankVariable(0, value);
	} else {
		throw makeExpected(fes.location, "one or two variables after foreach");
	}
}

bool isInternalVariable(ir.Class c, ir.Variable v)
{
	foreach (ivar; c.ifaceVariables) {
		if (ivar is v) {
			return true;
		}
	}
	return v is c.typeInfo || v is c.vtableVariable || v is c.initVariable;
}

void writeVariableAssignsIntoCtors(Context ctx, ir.Class _class)
{
	foreach (n; _class.members.nodes) {
		auto v = cast(ir.Variable) n;
		if (v is null || v.assign is null ||
			isInternalVariable(_class, v) ||
		   !(v.storage != ir.Variable.Storage.Local && 
		    v.storage != ir.Variable.Storage.Global)) {
			continue;
		}
		foreach (ctor; _class.userConstructors) {
			assert(ctor.thisHiddenParameter !is null);
			auto eref = buildExpReference(ctor.thisHiddenParameter.location, ctor.thisHiddenParameter, ctor.thisHiddenParameter.name);
			auto assign = buildAssign(ctor.location, buildAccess(ctor.location, eref, v.name), v.assign);
			auto stat = new ir.ExpStatement();
			stat.location = ctor.location;
			stat.exp = copyExp(assign);
			ctor._body.statements = stat ~ ctor._body.statements;
		}
		v.assign = null;
		if (v.type.isConst || v.type.isImmutable) {
			throw makeConstField(v);
		}
	}
}

class GotoReplacer : NullVisitor
{
public:
	override Status enter(ir.GotoStatement gs)
	{
		assert(exp !is null);
		if (gs.isCase && gs.exp is null) {
			gs.exp = copyExp(exp);
		}
		return Continue;
	}

public:
	ir.Exp exp;
}

/**
 * Given a switch statement, replace 'goto case' with an explicit
 * jump to the next case.
 */
void replaceGotoCase(Context ctx, ir.SwitchStatement ss)
{
	auto gr = new GotoReplacer();
	foreach_reverse (sc; ss.cases) {
		if (gr.exp !is null) {
			accept(sc.statements, gr);
		}
		gr.exp = sc.exps.length > 0 ? sc.exps[0] : sc.firstExp;
	}
}


/*
 *
 * Resolver functions.
 *
 */

/**
 * Resolves a Variable.
 */
void resolveVariable(Context ctx, ir.Variable v)
{
	auto done = ctx.lp.startResolving(v);
	ctx.isVarAssign = true;

	scope (success) {
		ctx.isVarAssign = false;
		done();
	}

	v.hasBeenDeclared = true;
	foreach (u; v.userAttrs) {
		ctx.lp.resolve(ctx.current, u);
	}

	// Fix up type as best as possible.
	accept(v.type, ctx.extyper);
	v.type = ctx.lp.resolve(ctx.current, v.type);

	bool inAggregate = (cast(ir.Aggregate) ctx.current.node) !is null;
	if (inAggregate && v.assign !is null &&
	    ctx.current.node.nodeType != ir.NodeType.Class &&
            (v.storage != ir.Variable.Storage.Global &&
             v.storage != ir.Variable.Storage.Local)) {
		throw makeAssignToNonStaticField(v);
	}

	if (inAggregate && (v.type.isConst || v.type.isImmutable)) {
		throw makeConstField(v);
	}

	replaceTypeOfIfNeeded(ctx, v.type);

	if (v.assign !is null) {
		handleIfStructLiteral(ctx, v.type, v.assign);
		acceptExp(v.assign, ctx.extyper);
		extypeAssign(ctx, v.assign, v.type);
	}

	replaceAutoIfNeeded(v.type);
	accept(v.type, ctx.extyper);
	v.isResolved = true;
}

void resolveFunction(Context ctx, ir.Function fn)
{
	auto done = ctx.lp.startResolving(fn);
	scope (success) done();

	if (fn.isAutoReturn) {
		fn.type.ret = buildVoid(fn.type.ret.location);
	}

	if (fn.type.isProperty &&
	    fn.type.params.length == 0 &&
	    isVoid(fn.type.ret)) {
		throw makeInvalidType(fn, buildVoid(fn.location));
	} else if (fn.type.isProperty &&
	           fn.type.params.length > 1) {
		throw makeWrongNumberOfArguments(fn, fn.type.params.length, isVoid(fn.type.ret) ? 0U : 1U);
	}

	fn.type = cast(ir.FunctionType)ctx.lp.resolve(fn.myScope.parent, fn.type);


	if (fn.name == "main" && fn.type.linkage == ir.Linkage.Volt) {

		if (fn.params.length == 0) {
			addParam(fn.location, fn, buildStringArray(fn.location), "");
		} else if (fn.params.length > 1) {
			throw makeInvalidMainSignature(fn);
		}

		auto arr = cast(ir.ArrayType) fn.type.params[0];
		if (arr is null ||
		    !isString(realType(arr.base)) ||
		    (!isVoid(fn.type.ret) && !isInt(fn.type.ret))) {
			throw makeInvalidMainSignature(fn);
		}
	}


	if (fn.nestStruct !is null &&
	    fn.thisHiddenParameter !is null &&
	    !ctx.isFunction) {
		auto cvar = copyVariableSmart(fn.thisHiddenParameter.location, fn.thisHiddenParameter);
		addVarToStructSmart(fn.nestStruct, cvar);
	}


	handleNestedThis(fn);
	handleNestedParams(ctx, fn);

	if ((fn.kind == ir.Function.Kind.Function ||
	     (cast(ir.Class) fn.myScope.parent.node) is null) &&
	    fn.isMarkedOverride) {
		throw makeMarkedOverrideDoesNotOverride(fn, fn);
	}

	replaceVarArgsIfNeeded(ctx.lp, fn);

	ctx.lp.resolve(ctx.current, fn.userAttrs);

	if (fn.type.homogenousVariadic && !isArray(realType(fn.type.params[$-1]))) {
		throw makeExpected(fn.params[$-1].location, "array type");
	}

	if (fn.outParameter.length > 0) {
		assert(fn.outContract !is null);
		auto l = fn.outContract.location;
		auto var = buildVariableSmart(l, copyTypeSmart(l, fn.type.ret), ir.Variable.Storage.Function, fn.outParameter);
		fn.outContract.statements = var ~ fn.outContract.statements;
		fn.outContract.myScope.addValue(var, var.name);
	}

	foreach (i, ref param; fn.params) {
		if (param.assign is null) {
			continue;
		}
		auto texp = cast(ir.TokenExp) param.assign;
		if (texp !is null) {
			continue;
		}

		// We don't extype TokenExp because we want it to be resolved
		// at the call site not where it was defined.
		acceptExp(param.assign, ctx.extyper);
		param.assign = evaluate(ctx.lp, ctx.current, param.assign);
	}

	if (fn.loadDynamic && fn._body !is null) {
		throw makeCannotLoadDynamic(fn, fn);
	}

	fn.isResolved = true;
}

/**
 * If type casting were to be strict, type T could only
 * go to type T without an explicit cast. Implicit casts
 * are places where the language deems automatic conversion
 * safe enough to insert casts for the user.
 *
 * Thus, the primary job of extyper ('explicit typer') is
 * to insert casts where an implicit conversion has taken place.
 *
 * The second job of extyper is to make any implicit or
 * inferred types or expressions concrete -- for example,
 * to make const i = 2 become const int = 2.
 */
class ExTyper : NullVisitor, Pass
{
public:
	Context ctx;

public:
	this(LanguagePass lp)
	{
		ctx = new Context(lp, this);
	}


	/*
	 *
	 * Pass.
	 *
	 */

	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close()
	{
	}


	/*
	 *
	 * Called by the LanguagePass.
	 *
	 */

	/**
	 * For out of band checking of Variables.
	 */
	void resolve(ir.Scope current, ir.Variable v)
	{
		ctx.setupFromScope(current);
		scope (success) ctx.reset();

		accept(v, this);
	}

	/**
	 * For out of band checking of Functions.
	 */
	void resolve(ir.Scope current, ir.Function fn)
	{
		ctx.setupFromScope(current);
		scope (success) ctx.reset();

		resolveFunction(ctx, fn);
	}

	/**
	 * For out of band checking of UserAttributes.
	 */
	void transform(ir.Scope current, ir.Attribute a)
	{
		ctx.setupFromScope(current);
		scope (exit) ctx.reset();

		basicValidateUserAttribute(ctx.lp, ctx.current, a);

		auto ua = a.userAttribute;
		assert(ua !is null);

		foreach (i, ref arg; a.arguments) {
			extypeAssign(ctx, a.arguments[i], ua.fields[i].type);
			acceptExp(a.arguments[i], this);
		}
	}

	void transform(ir.Scope current, ir.EnumDeclaration ed)
	{
		ctx.setupFromScope(current);
		scope (exit) ctx.reset();

		ir.EnumDeclaration[] edStack;
		ir.Exp prevExp;

		do {
			edStack ~= ed;
			if (ed.assign !is null) {
				break;
			}

			ed = ed.prevEnum;
			if (ed is null) {
				break;
			}

			if (ed.resolved) {
				prevExp = ed.assign;
				break;
			}
		} while (true);

		foreach_reverse (e; edStack) {
			resolve(e, prevExp);
			prevExp = e.assign;
		}
	}

	private void resolve(ir.EnumDeclaration ed, ir.Exp prevExp)
	{
		ed.type = ctx.lp.resolve(ctx.current, ed.type);

		if (ed.assign is null) {
			if (prevExp is null) {
				ed.assign = buildConstantInt(ed.location, 0);
			} else {
				auto loc = ed.location;
				auto prevType = getExpType(ctx.lp, prevExp, ctx.current);
				if (!isIntegral(prevType)) {
					throw makeTypeIsNot(ed, prevType, buildInt(ed.location));
				}

				ed.assign = evaluate(ctx.lp, ctx.current, buildAdd(loc, copyExp(prevExp), buildConstantInt(loc, 1)));
			}
		} else {
			acceptExp(ed.assign, this);
			if (needsEvaluation(ed.assign)) {
				ed.assign = evaluate(ctx.lp, ctx.current, ed.assign);
			}
		}

		extypeAssign(ctx, ed.assign, ed.type);
		replaceAutoIfNeeded(ed.type);
		accept(ed.type, this);

		ed.resolved = true;
	}


	/*
	 *
	 * Visitor
	 *
	 */

	override Status enter(ir.Module m)
	{
		ctx.enter(m);
		return Continue;
	}

	override Status leave(ir.Module m)
	{
		ctx.leave(m);
		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		ctx.lp.resolve(a);
		return ContinueParent;
	}

	override Status enter(ir.Struct s)
	{
		ctx.lp.actualize(s);
		ctx.enter(s);
		return Continue;
	}

	override Status leave(ir.Struct s)
	{
		checkAnonymousVariables(ctx, s);
		ctx.leave(s);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		ctx.lp.actualize(i);
		ctx.enter(i);
		return Continue;
	}

	override Status leave(ir._Interface i)
	{
		ctx.leave(i);
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		ctx.lp.actualize(u);
		ctx.enter(u);
		return Continue;
	}

	override Status leave(ir.Union u)
	{
		checkAnonymousVariables(ctx, u);
		ctx.leave(u);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		ctx.lp.actualize(c);
		ctx.enter(c);
		return Continue;
	}

	override Status leave(ir.Class c)
	{
		checkAnonymousVariables(ctx, c);
		writeVariableAssignsIntoCtors(ctx, c);
		ctx.leave(c);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		ctx.lp.resolveNamed(e);
		ctx.enter(e);
		return Continue;
	}

	override Status leave(ir.Enum e)
	{
		ctx.leave(e);
		return Continue;
	}

	override Status enter(ir.UserAttribute ua)
	{
		ctx.lp.actualize(ua);
		// Everything is done by actualize.
		return ContinueParent;
	}

	override Status enter(ir.EnumDeclaration ed)
	{
		ctx.lp.resolve(ctx.current, ed);
		return ContinueParent;
	}

	override Status enter(ir.StorageType st)
	{
		return Continue;
	}

	override Status enter(ir.FunctionParam p)
	{
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		if (!v.isResolved) {
			resolveVariable(ctx, v);
		}
		return ContinueParent;
	}

	override Status enter(ir.Function fn)
	{
		if (!fn.isResolved) {
			resolveFunction(ctx, fn);
		}

		ctx.enter(fn);
		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		ctx.leave(fn);
		return Continue;
	}


	/*
	 *
	 * Statements.
	 *
	 */

	override Status enter(ir.WithStatement ws)
	{
		acceptExp(ws.exp, this);

		auto e = cast(ir.Unary) ws.exp;
		auto type = getExpType(ctx.lp, ws.exp, ctx.current);
		if (e !is null && realType(type).nodeType == ir.NodeType.Class) {
			auto var = buildVariableSmart(ws.block.location, type, ir.Variable.Storage.Function, ws.block.myScope.genAnonIdent());
			var.assign = e;
			var.isResolved = true;
			ws.block.statements = var ~ ws.block.statements;
			ws.exp = buildExpReference(var.location, var, var.name);
		}

		ctx.pushWith(ws.exp);
		accept(ws.block, this);
		ctx.popWith(ws.exp);

		return ContinueParent;
	}

	override Status enter(ir.ReturnStatement ret)
	{
		auto fn = getParentFunction(ctx.current);
		if (fn is null) {
			throw panic(ret, "return statement outside of function.");
		}

		if (ret.exp !is null) {
			acceptExp(ret.exp, this);
			auto retType = getExpType(ctx.lp, ret.exp, ctx.current);
			if (fn.isAutoReturn) {
				fn.type.ret = copyTypeSmart(retType.location, getExpType(ctx.lp, ret.exp, ctx.current));
				if (cast(ir.NullType)fn.type.ret !is null) {
					fn.type.ret = buildVoidPtr(ret.location);
				}
			}
			if (retType.isScope && mutableIndirection(retType)) {
				throw makeNoReturnScope(ret.location);
			}
			extypeAssign(ctx, ret.exp, fn.type.ret);
		} else if (!isVoid(realType(fn.type.ret))) {
			// No return expression on function returning a value.
			throw makeReturnValueExpected(ret.location, fn.type.ret);
		}

		return ContinueParent;
	}

	override Status enter(ir.IfStatement ifs)
	{
		auto l = ifs.location;
		if (ifs.exp !is null) {
			acceptExp(ifs.exp, this);
		}

		if (ifs.autoName.length > 0) {
			assert(ifs.exp !is null);
			assert(ifs.thenState !is null);

			auto t = getExpType(ctx.lp, ifs.exp, ctx.current);
			auto var = buildVariable(l,
					copyTypeSmart(l, t),
					ir.Variable.Storage.Function,
					ifs.autoName);

			// Resolve the variable making it propper and usable.
			resolveVariable(ctx, var);

			// A hack to work around exp getting resolved twice.
			var.assign = ifs.exp;

			auto eref = buildExpReference(l, var);
			ifs.exp = buildStatementExp(l, [var], eref);

			// Add it to its proper scope.
			ifs.thenState.myScope.addValue(var, var.name);
		}

		// Need to do this after any autoName rewriting.
		if (ifs.exp !is null) {
			implicitlyCastToBool(ctx, ifs.exp);
		}

		if (ifs.thenState !is null) {
			accept(ifs.thenState, this);
		}

		if (ifs.elseState !is null) {
			accept(ifs.elseState, this);
		}

		return ContinueParent;
	}

	override Status enter(ir.ForeachStatement fes)
	{
		if (fes.beginIntegerRange !is null) {
			assert(fes.endIntegerRange !is null);
			acceptExp(fes.beginIntegerRange, this);
			acceptExp(fes.endIntegerRange, this);
		}
		extypeForeach(ctx, fes);
		ctx.enter(fes.block);
		foreach (ivar; fes.itervars) {
			accept(ivar, this);
		}
		if (fes.aggregate !is null) {
			auto aggType = realType(getExpType(ctx.lp, fes.aggregate, ctx.current));
			if (fes.itervars.length == 2 &&
				(aggType.nodeType == ir.NodeType.StaticArrayType || 
				aggType.nodeType == ir.NodeType.ArrayType)) {
				auto keysz = size(ctx.lp, fes.itervars[0].type);
				auto sizetsz = size(ctx.lp, buildSizeT(fes.location, ctx.lp));
				if (keysz < sizetsz) {
					throw makeError(fes.location, format("index var '%s' isn't large enough to hold a size_t.", fes.itervars[0].name));
				}
			}
		}
		// fes.aggregate is visited by extypeForeach
		foreach (ctxment; fes.block.statements) {
			accept(ctxment, this);
		}
		ctx.leave(fes.block);
		return ContinueParent;
	}

	override Status enter(ir.ForStatement fs)
	{
		ctx.enter(fs.block);
		foreach (i; fs.initVars) {
			accept(i, this);
		}
		foreach (ref i; fs.initExps) {
			acceptExp(i, this);
		}

		if (fs.test !is null) {
			acceptExp(fs.test, this);
			implicitlyCastToBool(ctx, fs.test);
		}
		foreach (ref increment; fs.increments) {
			acceptExp(increment, this);
		}
		foreach (ctxment; fs.block.statements) {
			accept(ctxment, this);
		}
		ctx.leave(fs.block);

		return ContinueParent;
	}

	override Status enter(ir.WhileStatement ws)
	{
		if (ws.condition !is null) {
			acceptExp(ws.condition, this);
			implicitlyCastToBool(ctx, ws.condition);
		}

		accept(ws.block, this);

		return ContinueParent;
	}

	override Status enter(ir.DoStatement ds)
	{
		accept(ds.block, this);

		if (ds.condition !is null) {
			acceptExp(ds.condition, this);
			implicitlyCastToBool(ctx, ds.condition);
		}

		return ContinueParent;
	}

	override Status enter(ir.SwitchStatement ss)
	{
		acceptExp(ss.condition, this);

		foreach (ref wexp; ss.withs) {
			acceptExp(wexp, this);
			ctx.pushWith(wexp);
		}

		foreach (_case; ss.cases) {
			accept(_case, this);
		}

		verifySwitchStatement(ctx, ss);
		replaceGotoCase(ctx, ss);

		foreach_reverse(wexp; ss.withs) {
			ctx.popWith(wexp);
		}
		return ContinueParent;
	}

	override Status leave(ir.ThrowStatement t)
	{
		extypeThrow(ctx, t);
		return Continue;
	}

	override Status enter(ir.AssertStatement as)
	{
		if (!as.isStatic) {
			return Continue;
		}
		as.condition = evaluate(ctx.lp, ctx.current, as.condition);
		as.message = evaluate(ctx.lp, ctx.current, as.message);
		auto cond = cast(ir.Constant) as.condition;
		auto msg = cast(ir.Constant) as.message;
		if ((cond is null || msg is null) || (!isBool(cond.type) || !isString(msg.type))) {
			throw panicUnhandled(as, "non simple static asserts (bool and string literal only).");
		}
		if (!cond.u._bool) {
			throw makeStaticAssert(as, msg._string);
		}
		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		ctx.enter(bs);
		// Translate runtime asserts before processing the block.
		for (size_t i = 0; i < bs.statements.length; i++) {
			auto as = cast(ir.AssertStatement) bs.statements[i];
			if (as is null || as.isStatic) {
				continue;
			}
			bs.statements[i] = transformRuntimeAssert(ctx, as);
		}
		return Continue;
	}

	override Status leave(ir.BlockStatement bs)
	{
		ctx.leave(bs);
		return Continue;
	}


	/*
	 *
	 * Types.
	 *
	 */

	override Status enter(ir.FunctionType ftype)
	{
		replaceTypeOfIfNeeded(ctx, ftype.ret);
		return Continue;
	}

	override Status enter(ir.DelegateType dtype)
	{
		replaceTypeOfIfNeeded(ctx, dtype.ret);
		return Continue;
	}


	/*
	 *
	 * Expressions.
	 *
	 */

	override Status leave(ref ir.Exp exp, ir.Typeid _typeid)
	{
		if (_typeid.ident.length > 0) {
			auto store = lookup(ctx.lp, ctx.current, _typeid.location, _typeid.ident);
			if (store is null) {
				throw makeFailedLookup(_typeid, _typeid.ident);
			}
			switch (store.kind) with (ir.Store.Kind) {
			case Type:
				_typeid.type = buildTypeReference(_typeid.location, cast(ir.Type) store.node, _typeid.ident);
				assert(_typeid.type !is null);
				break;
			case Value, EnumDeclaration, FunctionParam, Function:
				auto decl = cast(ir.Declaration) store.node;
				_typeid.exp = buildExpReference(_typeid.location, decl, _typeid.ident);
				break;
			default:
				throw panicUnhandled(_typeid, "store kind");
			}
			_typeid.ident = null;
		}
		if (_typeid.exp !is null) {
			_typeid.type = getExpType(ctx.lp, _typeid.exp, ctx.current);
			if ((cast(ir.Aggregate) _typeid.type) !is null) {
				_typeid.type = buildTypeReference(_typeid.type.location, _typeid.type);
			} else {
				_typeid.type = copyType(_typeid.type);
			}
			_typeid.exp = null;
		}

		_typeid.type = ctx.lp.resolve(ctx.current, _typeid.type);
		replaceTypeOfIfNeeded(ctx, _typeid.type);
		return Continue;
	}

	/// If this is an assignment to a @property function, turn it into a function call.
	override Status enter(ref ir.Exp e, ir.BinOp bin)
	{
		if (bin.left.nodeType == ir.NodeType.Postfix) {
			auto postfix = cast(ir.Postfix) bin.left;
			extypePostfix(ctx, bin.left, postfix, e);
		} else if (bin.left.nodeType == ir.NodeType.IdentifierExp) {
			auto ie = cast(ir.IdentifierExp) bin.left;
			extypeIdentifierExp(ctx, bin.left, ie, e);
		} else {
			acceptExp(bin.left, this);
		}
		acceptExp(bin.right, this);

		// If not rewritten.
		if (e is bin) {
			extypeBinOp(ctx, bin, e);
		}
		return ContinueParent;
	}

	override Status enter(ref ir.Exp exp, ir.Postfix postfix)
	{
		extypePostfix(ctx, exp, postfix, null);
		return ContinueParent;
	}

	override Status enter(ref ir.Exp exp, ir.Unary _unary)
	{
		if (_unary.type !is null) {
			_unary.type = ctx.lp.resolve(ctx.current, _unary.type);
		}
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Unary _unary)
	{
		if (_unary.type !is null) {
			replaceTypeOfIfNeeded(ctx, _unary.type);
		}
		extypeUnary(ctx, exp, _unary);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Ternary ternary)
	{
		extypeTernary(ctx, ternary);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.TypeExp te)
	{
		te.type = ctx.lp.resolve(ctx.current, te.type);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.VaArgExp vaexp)
	{
		vaexp.type = ctx.lp.resolve(ctx.current, vaexp.type);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.VaArgExp vaexp)
	{
		if (!isLValue(vaexp.arg)) {
			throw makeVaFooMustBeLValue(vaexp.arg.location, "va_exp");
		}
		if (ctx.currentFunction.type.linkage == ir.Linkage.C) {
			if (vaexp.type.nodeType != ir.NodeType.PrimitiveType && vaexp.type.nodeType != ir.NodeType.PointerType) {
				throw makeCVaArgsOnlyOperateOnSimpleTypes(vaexp.location);
			}
			vaexp.arg = buildAddrOf(vaexp.location, copyExp(vaexp.arg));
		} else {
			exp = buildVaArgCast(vaexp.location, vaexp);
		}
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.ExpReference eref)
	{
		ctx.lp.resolve(ctx.current, eref);
		replaceExpReferenceIfNeeded(ctx, null, exp, eref);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.IdentifierExp ie)
	{
		extypeIdentifierExp(ctx, exp, ie, null);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.Constant constant)
	{
		constant.type = ctx.lp.resolve(ctx.current, constant.type);
		if (constant._string == "$" && isIntegral(constant.type)) {
			if (ctx.lastIndexChild is null) {
				throw makeDollarOutsideOfIndex(constant);
			}
			auto l = constant.location;
			// Rewrite $ to (arrayName.length).
			exp = buildAccess(l, copyExp(ctx.lastIndexChild), "length");
		}
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.StructLiteral sl)
	{
		extypeStructLiteral(ctx, sl);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.TokenExp fexp)
	{
		if (fexp.type == ir.TokenExp.Type.File) {
			string fname = fexp.location.filename;
			version (Windows) {
				fname = fname.replace("\\", "/");
			}
			exp = buildConstantString(fexp.location, fname);
			return Continue;
		} else if (fexp.type == ir.TokenExp.Type.Line) {
			exp = buildConstantInt(fexp.location, cast(int) fexp.location.line);
			return Continue;
		}

		char[] buf;
		void sink(string s)
		{
			buf ~= s;
		}
		version (Volt) {
			// @TODO fix this.
			// auto buf = new StringSink();
			// auto pp = new PrettyPrinter("\t", buf.sink);
			auto pp = new PrettyPrinter("\t", cast(void delegate(string))sink);
		} else {
			auto pp = new PrettyPrinter("\t", &sink);
		}

		string[] names;
		ir.Scope scop = ctx.current;
		ir.Function foundFunction;
		while (scop !is null) {
			if (scop.node.nodeType != ir.NodeType.BlockStatement) {
				names ~= scop.name;
			}
			if (scop.node.nodeType == ir.NodeType.Function) {
				foundFunction = cast(ir.Function) scop.node;
			}
			scop = scop.parent;
		}
		if (foundFunction is null) {
			throw makeFunctionNameOutsideOfFunction(fexp);
		}

		if (fexp.type == ir.TokenExp.Type.PrettyFunction) {
			pp.transformType(foundFunction.type.ret);
			buf ~= " ";
		}

		foreach_reverse (i, name; names) {
			buf ~= name ~ (i > 0 ? "." : "");
		}

		if (fexp.type == ir.TokenExp.Type.PrettyFunction) {
			buf ~= "(";
			foreach (i, ptype; ctx.currentFunction.type.params) {
				pp.transformType(ptype);
				if (i < ctx.currentFunction.type.params.length - 1) {
					buf ~= ", ";
				}
			}
			buf ~= ")";
		}

		version (Volt) {
			auto str = new string(buf);
		} else {
			auto str = buf.idup;
		}
		exp = buildConstantString(fexp.location, str);
		return Continue;
	}
}
