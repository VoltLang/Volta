// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.extyper;

import std.algorithm : remove;
import std.array : insertInPlace;
import std.conv : to;
import std.string : format, translate;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.errors;
import volt.interfaces;
import volt.util.string;
import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.visitor.prettyprinter;
import volt.semantic.userattrresolver;
import volt.semantic.classify;
import volt.semantic.classresolver;
import volt.semantic.lookup;
import volt.semantic.typer;
import volt.semantic.util;
import volt.semantic.ctfe;
import volt.semantic.overload;
import volt.semantic.nested;
import volt.semantic.context;

/**
 * This handles the auto that has been filled in, removing the auto storage.
 */
void replaceStorageIfNeeded(ref ir.Type type)
{
	auto storage = cast(ir.StorageType) type;
	if (storage !is null && storage.type == ir.StorageType.Kind.Auto && storage.base !is null) {
		type = storage.base;
	}
}

/**
 * This handles implicitly typing null.
 * Generic function used by assign and other functions.
 */
bool handleIfNull(Context ctx, ir.Type left, ref ir.Exp right)
{
	auto rightType = getExpType(ctx.lp, right, ctx.current);
	if (rightType.nodeType != ir.NodeType.NullType) {
		return false;
	}

	return handleNull(left, right, rightType) !is null;
}

/**
 * This handles implicitly typing a struct literal.
 *
 * While generic currently only used by extypeAssign.
 */
bool handleIfStructLiteral(Context ctx, ir.Type left, ref ir.Exp right)
{
	auto asLit = cast(ir.StructLiteral) right;
	if (asLit is null)
		return false;

	assert(asLit !is null);

	auto asStruct = cast(ir.Struct) realType(left);
	if (asStruct is null) {
		throw makeBadImplicitCast(right, getExpType(ctx.lp, right, ctx.current), left);
	}

	ir.Type[] types = getStructFieldTypes(asStruct);

	if (types.length < asLit.exps.length) {
		throw makeBadImplicitCast(right, getExpType(ctx.lp, right, ctx.current), left);
	}

	foreach (i, ref sexp; asLit.exps) {
		extypeAssign(ctx, sexp, types[i]);
	}

	asLit.type = buildTypeReference(right.location, asStruct, asStruct.name);
	return true;
}

/**
 * Implicitly convert PrimitiveTypes to bools for 'if' and friends.
 */
void extypeCastToBool(Context ctx, ref ir.Exp exp)
{
	auto t = getExpType(ctx.lp, exp, ctx.current);
	if (t.nodeType == ir.NodeType.PrimitiveType) {
		auto asPrimitive = cast(ir.PrimitiveType) realType(t);
		if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
			return;
		}
	}
	exp = buildCastToBool(exp.location, exp);
}

/**
 * This deals with one side of an assign statement being 
 * a storage type and the other not.
 * It allows scope and const to decay if the left hand side
 * isn't mutably indirect. It also allows types to be converted
 * into scoped ones.
 */
void extypeAssignHandleStorage(Context ctx, ref ir.Exp exp, ir.Type ltype)
{
	auto rtype = realType(getExpType(ctx.lp, exp, ctx.current));
	ltype = realType(ltype);
	if (ltype.nodeType != ir.NodeType.StorageType &&
	    rtype.nodeType == ir.NodeType.StorageType) {
		auto asStorageType = cast(ir.StorageType) rtype;
		assert(asStorageType !is null);
		if (asStorageType.type == ir.StorageType.Kind.Scope) {
			if (mutableIndirection(asStorageType.base)) {
				throw makeBadImplicitCast(exp, rtype, ltype);
			}
			exp = buildCastSmart(asStorageType.base, exp);
		}

		if (effectivelyConst(rtype)) {
			if (!mutableIndirection(asStorageType.base)) {
				exp = buildCastSmart(asStorageType.base, exp);
			} else {
				throw makeBadImplicitCast(exp, rtype, ltype);
			}
		}
	} else if (ltype.nodeType == ir.NodeType.StorageType &&
	           rtype.nodeType != ir.NodeType.StorageType) {
		auto asStorageType = cast(ir.StorageType) ltype;
		/* Scope is always the first StorageType, so we don't have to
		 * worry about StorageType chains.
		 */
		if (asStorageType.type == ir.StorageType.Kind.Scope) {
			exp = buildCastSmart(asStorageType, exp);
		}
	}
}

/**
 * This handles implicitly casting a const type to a mutable type,
 * if the underlying type has no mutable indirection.
 */
void extypePassHandleStorage(Context ctx, ref ir.Exp exp, ir.Type ltype)
{
	auto rtype = realType(getExpType(ctx.lp, exp, ctx.current));
	ltype = realType(ltype);
	if (ltype.nodeType != ir.NodeType.StorageType &&
	    rtype.nodeType == ir.NodeType.StorageType) {
		auto asStorageType = cast(ir.StorageType) rtype;
		assert(asStorageType !is null);

		if (effectivelyConst(rtype)) {
			if (!mutableIndirection(asStorageType.base)) {
				exp = buildCastSmart(asStorageType.base, exp);
			} else {
				throw makeBadImplicitCast(exp, rtype, ltype);
			}
		}
	}
}


/**
 * Forbids mutably indirect types being implicitly casted to scope.
 */
void rejectBadScopeAssign(Context ctx, ref ir.Exp exp, ir.Type type)
{
	auto storage = cast(ir.StorageType) realType(type);
	if (storage is null) {
		return;
	}
	if (mutableIndirection(storage.base)) {
		if (!ctx.isVarAssign || (ctx.current.node.nodeType != ir.NodeType.Function && ctx.current.node.nodeType != ir.NodeType.BlockStatement)) {
			throw makeBadImplicitCast(exp, type, storage);
		}
	}
}

void extypeAssignTypeReference(Context ctx, ref ir.Exp exp, ir.TypeReference tr)
{
	extypeAssign(ctx, exp, tr.type);
}

void stripPointerBases(ir.Type toType, ref uint flag)
{
	switch (toType.nodeType) {
	case ir.NodeType.PointerType:
		auto ptr = cast(ir.PointerType) toType;
		assert(ptr !is null);
		ptr.base = flagitiseStorage(ptr.base, flag);
		stripPointerBases(ptr.base, flag);
		break;
	default:
		break;
	}
}

void stripArrayBases(ir.Type toType, ref uint flag)
{
	switch (toType.nodeType) {
	case ir.NodeType.ArrayType:
		auto arr = cast(ir.ArrayType) toType;
		assert(arr !is null);
		arr.base = flagitiseStorage(arr.base, flag);
		stripArrayBases(arr.base, flag);
		break;
	default:
		break;
	}
}

void appendDefaultArguments(Context ctx, ir.Location loc, ref ir.Exp[] arguments, ir.Function fn)
{
	if (fn !is null && arguments.length < fn.params.length) {
		ir.Exp[] overflow;
		foreach (p; fn.params[arguments.length .. $]) {
			if (p.assign is null) {
				throw makeExpected(loc, "default argument");
			}
			overflow ~= p.assign;
		}
		auto oldLength = arguments.length;
		foreach (i, ee; overflow) {
			auto constant = cast(ir.Constant) ee;
			if (constant is null) {
				auto texp = cast(ir.TokenExp) ee;
				assert(texp !is null);
				texp.location = loc;
				arguments ~= texp;
			} else {
				arguments ~= copyExp(loc, ee);
			}
			acceptExp(arguments[$-1], ctx.etyper);
		}
	}
}

/**
 * Handles implicit pointer casts. To void*, immutable(T)* to const(T)*
 * T* to const(T)* and the like.
 */
void extypeAssignPointerType(Context ctx, ref ir.Exp exp, ir.PointerType ptr, uint flag)
{
	ir.PointerType pcopy = cast(ir.PointerType) copyTypeSmart(exp.location, ptr);
	assert(pcopy !is null);
	stripPointerBases(pcopy, flag);

	// string literals implicitly convert to typeof(string.ptr)
	auto constant = cast(ir.Constant) exp;
	if (constant !is null && constant._string.length != 0) {
		exp = buildAccess(exp.location, exp, "ptr");
	}

	auto type = ctx.overrideType !is null ? ctx.overrideType : realType(getExpType(ctx.lp, exp, ctx.current));

	auto storage = cast(ir.StorageType) type;
	if (storage !is null) {
		type = storage.base;
	}

	auto rp = cast(ir.PointerType) type;
	if (rp is null) {
		throw makeBadImplicitCast(exp, type, pcopy);
	}
	ir.PointerType rcopy = cast(ir.PointerType) copyTypeSmart(exp.location, rp);
	assert(rcopy !is null);


	auto pbase = realBase(pcopy);
	auto rbase = realBase(rcopy);
	uint rflag, raflag;
	flagitiseStorage(rcopy, rflag);
	rcopy.base = flagitiseStorage(rp.base, raflag);
	rflag |= raflag;
	uint aflag;
	pcopy.base = flagitiseStorage(ptr.base, aflag);
	flag |= aflag;

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

	if (flag & ir.StorageType.STORAGE_CONST && !(rflag & ir.StorageType.STORAGE_SCOPE)) {
		exp = buildCastSmart(pcopy, exp);
		return;
	}

	if (rflag & ir.StorageType.STORAGE_IMMUTABLE && rflag & ir.StorageType.STORAGE_CONST) {
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

	auto lsize = size(lprim.type);
	auto rsize = size(rprim.type);

	auto lunsigned = isUnsigned(lprim.type);
	auto runsigned = isUnsigned(rprim.type);

	if (lunsigned != runsigned && !fitsInPrimitive(lprim, exp) && rsize >= lsize) {
		throw makeBadImplicitCast(exp, rprim, lprim);
	}

	if (rsize > lsize && !fitsInPrimitive(lprim, exp)) {
		throw makeBadImplicitCast(exp, rprim, lprim);
	}

	exp = buildCastSmart(lprim, exp);
}

/**
 * Handles converting child classes to parent classes.
 */
void extypeAssignClass(Context ctx, ref ir.Exp exp, ir.Class _class)
{
	auto type = realType(getExpType(ctx.lp, exp, ctx.current));
	assert(type !is null);

	auto rightClass = cast(ir.Class) type;
	if (rightClass is null) {
		throw makeBadImplicitCast(exp, type, _class);
	}
	ctx.lp.resolve(rightClass);

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
void extypeAssignCallableType(Context ctx, ref ir.Exp exp, ir.CallableType ctype)
{
	auto rtype = ctx.overrideType !is null ? ctx.overrideType : realType(getExpType(ctx.lp, exp, ctx.current));
	if (typesEqual(ctype, rtype)) {
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
	auto acopy = copyTypeSmart(exp.location, atype);
	stripArrayBases(acopy, flag);
	auto rtype = ctx.overrideType !is null ? ctx.overrideType : realType(getExpType(ctx.lp, exp, ctx.current));
	auto rarr = cast(ir.ArrayType) copyTypeSmart(exp.location, rtype);
	uint rflag;
	if (rarr !is null) {
		stripArrayBases(rarr, rflag);
	}
	bool badImmutable = (flag & ir.StorageType.STORAGE_IMMUTABLE) != 0 && (rflag & ir.StorageType.STORAGE_IMMUTABLE) == 0;
	if (typesEqual(acopy, rarr !is null ? rarr : rtype) && 
		!badImmutable && (flag & ir.StorageType.STORAGE_SCOPE) == 0) {
		return;
	}

	auto ctype = cast(ir.CallableType) atype;
	if (ctype !is null && ctype.homogenousVariadic && rarr is null) {
		return;
	}

	throw makeBadImplicitCast(exp, rtype, atype);
}

void extypeAssignAAType(Context ctx, ref ir.Exp exp, ir.AAType aatype)
{
	auto rtype = ctx.overrideType !is null ? ctx.overrideType : getExpType(ctx.lp, exp, ctx.current);
	if (exp.nodeType == ir.NodeType.AssocArray && typesEqual(aatype, rtype)) {
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
	    throw makeBadAAAssign(exp.location);
	}

	throw makeBadImplicitCast(exp, rtype, aatype);
}

ir.Type flagitiseStorage(ir.Type type, ref uint flag)
{
	auto storage = cast(ir.StorageType) type;
	while (storage !is null) {
		final switch (storage.type) with (ir.StorageType) {
		case Kind.Auto:
			flag |= STORAGE_AUTO;
			break;
		case Kind.Const:
			flag |= STORAGE_CONST;
			break;
		case Kind.Immutable:
			flag |= STORAGE_IMMUTABLE;
			break;
		case Kind.Scope:
			flag |= STORAGE_SCOPE;
			break;
		case Kind.Ref:
			flag |= STORAGE_REF;
			break;
		case Kind.Out:
			flag |= STORAGE_OUT;
			break;
		}
		type = storage.base;
		storage = cast(ir.StorageType) storage.base;
	}
	return type;
}



void handleAssign(Context ctx, ref ir.Type toType, ref ir.Exp exp, ref uint toFlag)
{
	auto rtype = getExpType(ctx.lp, exp, ctx.current);
	auto storage = cast(ir.StorageType) toType;
	if (storage !is null && storage.base is null) {
		if (rtype.nodeType == ir.NodeType.FunctionSetType) {
			throw makeCannotInfer(exp.location);
		}
		storage.base = copyTypeSmart(exp.location, rtype);
	}
	auto originalRtype = rtype;
	auto originalTo = toType;
	toType = flagitiseStorage(toType, toFlag);
	uint rflag;
	rtype = flagitiseStorage(rtype, rflag);
	if ((toFlag & ir.StorageType.STORAGE_SCOPE) != 0 && ctx.isVarAssign) {
		exp = buildCastSmart(exp.location, toType, exp);
	} else if ((toFlag & ir.StorageType.STORAGE_SCOPE) != 0 && (rflag & ir.StorageType.STORAGE_SCOPE) == 0 && mutableIndirection(toType)) {
		throw makeBadImplicitCast(exp, originalRtype, originalTo);
	} else if ((rflag & ir.StorageType.STORAGE_CONST) != 0 && !(toFlag & ir.StorageType.STORAGE_CONST) && mutableIndirection(toType)) {
		throw makeBadImplicitCast(exp, originalRtype, originalTo);
	} else if (mutableIndirection(toType) && (rflag & ir.StorageType.STORAGE_SCOPE) != 0) {
		throw makeBadImplicitCast(exp, originalRtype, originalTo);
	}
}

void extypeAssignDispatch(Context ctx, ref ir.Exp exp, ir.Type type)
{
	uint flag;
	handleAssign(ctx, type, exp, flag);
	switch (type.nodeType) {
	case ir.NodeType.StorageType:
		auto storage = cast(ir.StorageType) type;
		extypeAssignDispatch(ctx, exp, storage.base);
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
	case ir.NodeType.AAType:
		auto aatype = cast(ir.AAType) type;
		extypeAssignAAType(ctx, exp, aatype);
		break;
	case ir.NodeType.Struct:
	case ir.NodeType.Union:
		auto rtype = getExpType(ctx.lp, exp, ctx.current);
		if (typesEqual(type, rtype)) {
			return;
		}
		throw makeBadImplicitCast(exp, rtype, type);
	default:
		throw panicUnhandled(exp, to!string(type.nodeType));
	}
}

void extypePass(Context ctx, ref ir.Exp exp, ir.Type type)
{
	ensureResolved(ctx.lp, ctx.current, type);
	auto storage = cast(ir.StorageType) type;
	if (storage !is null && storage.type == ir.StorageType.Kind.Scope) {
		type = storage.base;
	}
	extypeAssign(ctx, exp, type);
}

void extypeAssign(Context ctx, ref ir.Exp exp, ir.Type type)
{
	ensureResolved(ctx.lp, ctx.current, type);
	if (handleIfStructLiteral(ctx, type, exp)) return;
	if (handleIfNull(ctx, type, exp)) return;

	extypeAssignDispatch(ctx, exp, type);
}

/**
 * Replace IdentifierExps with ExpReferences.
 */
void extypeIdentifierExp(Context ctx, ref ir.Exp e, ir.IdentifierExp i)
{
	auto current = i.globalLookup ? getModuleFromScope(ctx.current).myScope : ctx.current;
	if (i.type is null) {
		i.type = declTypeLookup(i.location, ctx.lp, current, i.value);
	}

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
		if (!var.hasBeenDeclared && var.storage == ir.Variable.Storage.Function) {
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
		foreach (fn; store.functions) {
			if (fn.nestedHiddenParameter !is null && store.functions.length > 1) {
				throw makeCannotOverloadNested(fn, fn);
			} else if (fn.nestedHiddenParameter !is null) {
				_ref.decl = store.functions[0];
				e = _ref;
				return;
			}
		}
		_ref.decl = buildSet(i.location, store.functions);
		e = _ref;
		auto fset = cast(ir.FunctionSet) _ref.decl;
		if (fset !is null) fset.reference = _ref;
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
	case Alias:
	case Scope:
		throw panicUnhandled(i, i.value);
	}
}

/**
 * Turns identifier postfixes into CreateDelegates, and resolves property function
 * calls in postfixes, type safe varargs, and explicit constructor calls.
 */
void extypeLeavePostfix(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	ir.Postfix[] postfixes;
	ir.Postfix currentPostfix = postfix;
	do {
		postfixes ~= currentPostfix;
		currentPostfix = cast(ir.Postfix) currentPostfix.child;
	} while (currentPostfix !is null);

	if (postfix.op != ir.Postfix.Op.Call) {
		auto type = getExpType(ctx.lp, postfix.child, ctx.current);
		/* If we end up with a identifier postfix that points
		 * at a struct, and retrieves a member function, then
		 * transform the op from Identifier to CreatePostfix.
		 */
		if (postfix.identifier !is null) {
			auto asStorage = cast(ir.StorageType) realType(type);
			if (asStorage !is null && canTransparentlyReferToBase(asStorage)) {
				type = asStorage.base;
			}

			auto tr = cast(ir.TypeReference) type;
			if (tr !is null) {
				type = tr.type;
			}

			if (type.nodeType != ir.NodeType.Struct &&
			    type.nodeType != ir.NodeType.Union &&
			    type.nodeType != ir.NodeType.Class) {
				return;
			}

			/// @todo this is probably an error.
			auto aggScope = getScopeFromType(type);
			auto store = lookupAsThisScope(ctx.lp, aggScope, postfix.location, postfix.identifier.value);
			if (store is null) {
				throw makeNotMember(postfix, type, postfix.identifier.value);
			}

			if (store.kind != ir.Store.Kind.Function) {
				return;
			}

			assert(store.functions.length > 0, store.name);

			auto funcref = new ir.ExpReference();
			funcref.location = postfix.identifier.location;
			auto _ref = cast(ir.ExpReference) postfix.child;
			if (_ref !is null) funcref.idents = _ref.idents;
			funcref.idents ~= postfix.identifier.value;
			funcref.decl = buildSet(postfix.identifier.location, store.functions, funcref);
			ir.FunctionSet set = cast(ir.FunctionSet) funcref.decl;
			if (set !is null) assert(set.functions.length > 0);
			postfix.op = ir.Postfix.Op.CreateDelegate;
			postfix.memberFunction = funcref;
		}

		propertyToCallIfNeeded(postfix.location, ctx.lp, exp, ctx.current, postfixes);

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
		assert(pchild !is null);
		assert(pchild.op == ir.Postfix.Op.CreateDelegate);
		eref = cast(ir.ExpReference) pchild.memberFunction;
	}
	assert(eref !is null);

	if (asFunctionSet !is null) {
		asFunctionSet.set.reference = eref;
		fn = selectFunction(ctx.lp, ctx.current, asFunctionSet.set, postfix.arguments, postfix.location);
		eref.decl = fn;
		asFunctionType = fn.type;

		if (reeval) {
			replaceExpReferenceIfNeeded(ctx, null, postfix.child, eref);
		}
	} else {
		fn = cast(ir.Function) eref.decl;
		asFunctionType = cast(ir.CallableType) realType(type);
		if (asFunctionType is null) {
			auto _storage = cast(ir.StorageType) type;
			if (_storage !is null) {
				asFunctionType = cast(ir.CallableType) _storage.base;
			}
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

	// Hand check va_start(vl) and va_end(vl), then modify their calls.
	if (fn is ctx.lp.vaStartFunc || fn is ctx.lp.vaEndFunc || fn is ctx.lp.vaCStartFunc || fn is ctx.lp.vaCEndFunc) {
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

	if (asFunctionType.isScope && postfix.child.nodeType == ir.NodeType.Postfix) {
		auto asPostfix = cast(ir.Postfix) postfix.child;
		auto parentType = getExpType(ctx.lp, asPostfix.child, ctx.current);
		if (mutableIndirection(parentType)) {
			auto asStorageType = cast(ir.StorageType) realType(parentType);
			if (asStorageType is null || asStorageType.type != ir.StorageType.Kind.Scope) {
				throw makeBadCall(postfix, asFunctionType);
			}
		}
	}

	if (asFunctionType.hasVarArgs &&
	    asFunctionType.linkage == ir.Linkage.Volt) {
		auto asExp = cast(ir.ExpReference) postfix.child;
		assert(asExp !is null);
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
			auto typeId = new ir.Typeid();
			typeId.location = postfix.location;
			typeId.type = copyTypeSmart(postfix.location, etype);
			typeidsLiteral.values ~= typeId;
			types ~= etype;
			sizes ~= size(postfix.location, ctx.lp, etype);
			totalSize += sizes[$-1];
		}

		postfix.arguments = argsSlice ~ typeidsLiteral ~ buildInternalArrayLiteralSliceSmart(postfix.location, buildArrayType(postfix.location, buildVoid(postfix.location)), types, sizes, totalSize, ctx.lp.memcpyFunc, varArgsSlice);
	}

	appendDefaultArguments(ctx, postfix.location, postfix.arguments, fn);
	if (!(asFunctionType.hasVarArgs || asFunctionType.params.length > 0 && asFunctionType.homogenousVariadic) &&
	    postfix.arguments.length != asFunctionType.params.length) {
		throw makeWrongNumberOfArguments(postfix, postfix.arguments.length, asFunctionType.params.length);
	}
	assert(asFunctionType.params.length <= postfix.arguments.length);
	foreach (i; 0 .. asFunctionType.params.length) {
		ir.StorageType.Kind stype;
		if (isRef(asFunctionType.params[i], stype)) { 
			if (!isLValue(postfix.arguments[i])) {
				throw makeNotLValue(postfix.arguments[i]);
			}
			if (stype == ir.StorageType.Kind.Ref && postfix.argumentTags[i] != ir.Postfix.TagKind.Ref) {
				throw makeNotTaggedRef(postfix.arguments[i]);
			}
			if (stype == ir.StorageType.Kind.Out && postfix.argumentTags[i] != ir.Postfix.TagKind.Out) {
				throw makeNotTaggedOut(postfix.arguments[i]);
			}
		}
		if (asFunctionType.homogenousVariadic && i == asFunctionType.params.length - 1) {
			auto etype = getExpType(ctx.lp, postfix.arguments[i], ctx.current);
			if (!isArray(etype)) {
				auto exps = postfix.arguments[i .. $];
				postfix.arguments[i] = buildInternalArrayLiteralSmart(exps[0].location, asFunctionType.params[i], exps);
				postfix.arguments.length = i + 1;
				break;
			}
		}
		extypePass(ctx, postfix.arguments[i], asFunctionType.params[i]);
	}

	if (thisCall) {
		// Explicit constructor call.
		auto tvar = getThisVar(postfix.location, ctx.lp, ctx.current);
		auto tref = buildExpReference(postfix.location, tvar, "this");
		postfix.arguments ~= buildCastToVoidPtr(postfix.location, tref);
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
bool replaceExpReferenceIfNeeded(Context ctx,
                                 ir.Type referredType, ref ir.Exp exp, ir.ExpReference eRef)
{
	// Hold onto your hats because this is ugly!
	// But this needs to be run after this function has early out
	// or rewritten the lookup.
	scope (success) {
		propertyToCallIfNeeded(exp.location, ctx.lp, exp, ctx.current, null);
	}

	// For vtable and property.
	if (eRef.rawReference) {
		return false;
	}
	
	// Early out on static vars.
	// Or function sets.
	auto decl = eRef.decl;
	final switch (decl.declKind) with (ir.Declaration.Kind) {
	case Function:
		auto asFn = cast(ir.Function)decl;
		if (isFunctionStatic(asFn)) {
			return false;
		}
		break;
	case Variable:
		auto asVar = cast(ir.Variable)decl;
		if (isVariableStatic(asVar)) {
			return false;
		}
		break;
	case FunctionParam:
		return false;
	case EnumDeclaration:
	case FunctionSet:
		return false;
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
	auto store = lookupOnlyThisScope(ctx.lp, expressionAgg.myScope, exp.location, ident);
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
		exp = buildCreateDelegate(eRef.location, thisRef, eRef);
	} else {
		exp = buildAccess(eRef.location, thisRef, ident);
	}

	return true;
}

/// Rewrite foo.prop = 3 into foo.prop(3).
void rewritePropertyFunctionAssign(Context ctx, ref ir.Exp e, ir.BinOp bin)
{
	if (bin.op != ir.BinOp.Op.Assign) {
		return;
	}
	auto asExpRef = cast(ir.ExpReference) bin.left;
	ir.Postfix asPostfix;
	string functionName;

	// Not a stand alone function, check if it's a member function.
	if (asExpRef is null) {
		asPostfix = cast(ir.Postfix) bin.left;
		if (asPostfix is null) {
			return;
		}
		if (asPostfix.op == ir.Postfix.Op.CreateDelegate) {
			asExpRef = asPostfix.memberFunction;
		} else if (asPostfix.op == ir.Postfix.Op.Identifier) {
			asExpRef = cast(ir.ExpReference) asPostfix.child;
			assert(asPostfix.identifier !is null);
			functionName = asPostfix.identifier.value;
		}
		if (asExpRef is null) {
			return;
		}
	}

	auto asFunction = cast(ir.Function) asExpRef.decl;
	// Classes aren't filled in yet, so try to see if it's one of those.
	if (asFunction is null) {
		auto asVariable = cast(ir.Variable) asExpRef.decl;
		if (asVariable is null) {
			return;
		}
		auto asTR = cast(ir.TypeReference) asVariable.type;
		if (asTR is null) {
			return;
		}
		auto asClass = cast(ir.Class) asTR.type;
		if (asClass is null) {
			return;
		}
		auto functionStore = lookupOnlyThisScope(ctx.lp, asClass.myScope, bin.location, functionName);
		if (functionStore is null) {
			return;
		}
		if (functionStore.functions.length != 1) {
			assert(functionStore.functions.length == 0);
			return;
		}
		asFunction = functionStore.functions[0];
		assert(asFunction !is null);
	}


	if (!asFunction.type.isProperty) {
		return;
	}
	if (asFunction.type.params.length != 1) {
		return;
	}
	auto call = buildCall(bin.location, asFunction, [bin.right], asFunction.name);
	assert(call.arguments.length == 1);
	assert(call.arguments[0] !is null);
	
	if (asPostfix !is null) {
		call.child = asPostfix;
	}
	e = call;
	return;
}

/**
 * Handles <type>.<identifier>, like 'int.min' and the like.
 */
void extypeTypeLookup(Context ctx, ref ir.Exp exp, ir.Postfix[] postfixIdents, ir.Type type)
{
	if (postfixIdents.length != 1) {
		throw makeExpected(type, "max or min");
	}
	if (postfixIdents[0].identifier.value != "max" && postfixIdents[0].identifier.value != "min") {
		throw makeExpected(type, "max or min");
	}
	bool max = postfixIdents[0].identifier.value == "max";

	auto pointer = cast(ir.PointerType) realType(type);
	if (pointer !is null) {
		if (ctx.lp.settings.isVersionSet("V_LP64")) {
			exp = buildConstantInt(type.location, max ? 8 : 0);
		} else {
			exp = buildConstantInt(type.location, max ? 4 : 0);
		}
		return;
	}

	auto prim = cast(ir.PrimitiveType) realType(type);
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
		exp = buildConstantUint(prim.location, max ? 4294967295U : 0);
		break;
	case Int:
		exp = buildConstantInt(prim.location, max ? 2147483647 : -2147483648);
		break;
	case Ulong:
		exp = buildConstantUlong(prim.location, max ? 18446744073709551615UL : 0);
		break;
	case Long:
		/* We use a ulong here because -9223372036854775808 is not converted as a string
		 * with a - on the front, but just the number 9223372036854775808 that is in a
		 * Unary minus expression. And because it's one more than will fit in a long, we
		 * have to use the next size up.
		 */
		exp = buildConstantUlong(prim.location, max ? 9223372036854775807UL : -9223372036854775808UL);
		break;
	case Float, Double, Real, Void:
		throw makeExpected(prim, "integral type");
	}
}

/**
 * Turn identifier postfixes into <ExpReference>.ident.
 */
void extypePostfixIdentifier(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	if (postfix.op != ir.Postfix.Op.Identifier)
		return;

	ir.Postfix[] postfixIdents; // In reverse order.
	ir.IdentifierExp identExp; // The top of the stack.
	ir.IdentifierExp firstExp;
	ir.Postfix currentP = postfix;

	while (true) {
		if (currentP.identifier is null)
			throw panic(currentP, "null identifier.");

		postfixIdents = [currentP] ~ postfixIdents;

		if (currentP.child.nodeType == ir.NodeType.Postfix) {
			auto child = cast(ir.Postfix) currentP.child;

			// for things like func().structVar;
			if (child.op != ir.Postfix.Op.Identifier) {
				return;
			}

			currentP = child;

		} else if (currentP.child.nodeType == ir.NodeType.IdentifierExp) {
			identExp = cast(ir.IdentifierExp) currentP.child;
			if (firstExp is null) {
				firstExp = identExp;
				assert(firstExp !is null);
			}
			break;
		} else if (currentP.child.nodeType == ir.NodeType.TypeExp) {
			auto typeExp = cast(ir.TypeExp) currentP.child;
			extypeTypeLookup(ctx, exp, postfixIdents, typeExp.type);
			return;
		} else {
			// For instance typeid(int).mangledName.
			return;
		}
	}

	ir.ExpReference _ref;
	ir.Location loc;
	string ident;
	string[] idents;

	/// Fillout _ref with data from ident.
	void filloutReference(ir.Store store)
	{
		_ref = new ir.ExpReference();
		_ref.location = loc;
		_ref.idents = idents;

		assert(store !is null);
		if (store.kind == ir.Store.Kind.Value) {
			auto var = cast(ir.Variable) store.node;
			tagNestedVariables(ctx, var, store, exp);
			assert(var !is null);
			_ref.decl = var;
		} else if (store.kind == ir.Store.Kind.Function) {
			assert(store.functions.length == 1);
			auto fn = store.functions[0];
			_ref.decl = fn;
		} else if (store.kind == ir.Store.Kind.FunctionParam) {
			auto fp = cast(ir.FunctionParam) store.node;
			assert(fp !is null);
			_ref.decl = fp;
		} else {
			throw panicUnhandled(_ref, to!string(store.kind));
		}

		// Sanity check.
		if (_ref.decl is null) {
			throw panic(_ref, "empty ExpReference declaration.");
		}
	}

	/**
	 * Our job here is to work trough the stack of postfixs and
	 * the top identifier exp looking for the first variable or
	 * function.
	 *
	 * pkg.mod.Class.Child.'staticVar'.field.anotherField;
	 *
	 * Would have 6 postfixs and IdentifierExp == "pkg".
	 * We would skip 3 postfixes and the IdentifierExp.
	 * Postfix "anotherField" ->
	 *   Postfix "field" ->
	 *     ExpReference "pkg.mod.Class.Child.staticVar".
	 *
	 *
	 * pkg.mod.'staticVar'.field;
	 *
	 * Would have 2 Postfixs and the IdentifierExp.
	 * We would should skip everything but one Postfix.
	 * Postfix "field" ->
	 *   ExpReference "pkg.mod.staticVar".
	 */

	ir.Scope _scope;
	ir.Store store;
	ir.Type lastType;

	// First do the identExp lookup.
	// postfix is in an unknown context at this point.
	{
		_scope = ctx.current;
		loc = identExp.location;
		ident = identExp.value;
		idents = [ident];

		/// @todo handle leading dot.
		assert(!identExp.globalLookup);

		store = lookup(ctx.lp, _scope, loc, ident);
	}

	// Now do the looping.
	do {
		if (store is null) {
			/// @todo keep track of what the context was that we looked into.
			throw makeFailedLookup(loc, ident);
		}

		lastType = null;
		final switch(store.kind) with (ir.Store.Kind) {
		case Type:
			lastType = cast(ir.Type) store.node;
			assert(lastType !is null);
			auto prim = cast(ir.PrimitiveType) lastType;
			if (prim !is null) {
				extypeTypeLookup(ctx, exp, postfixIdents, prim);
				return;
			}
			goto case Scope;
		case Scope:
			_scope = getScopeFromStore(store);
			if (_scope is null)
				throw panic(postfix, "missing scope");

			if (postfixIdents.length == 0)
				throw makeInvalidUseOfStore(postfix, store);

			postfix = postfixIdents[0];
			postfixIdents = postfixIdents[1 .. $];
			ident = postfix.identifier.value;
			loc = postfix.identifier.location;

			store = lookupOnlyThisScope(ctx.lp, _scope, loc, ident);
			idents = [ident] ~ idents;

			break;
		case EnumDeclaration:
			auto ed = cast(ir.EnumDeclaration)store.node;

			// If we want aggregate enums this needs to be fixed.
			assert(postfixIdents.length == 0);

			exp = copyExp(ed.assign);
			return;

		case Value:
		case Function:
		case FunctionParam:
			filloutReference(store);
			break;
		case Template:
			throw makeInvalidUseOfStore(postfix, store);
		case Alias:
			throw panic(postfix, "alias scope");
		}

	} while(_ref is null);

	assert(_ref !is null);


	// We are retriving a Variable or Function directly.
	if (postfixIdents.length == 0) {
		exp = _ref;
		replaceExpReferenceIfNeeded(ctx, lastType, exp, _ref);
	} else {
		postfix = postfixIdents[0];
		postfix.child = _ref;
		replaceExpReferenceIfNeeded(ctx, lastType, postfix.child, _ref);
	}
}

void extypePostfixIndex(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	if (postfix.op != ir.Postfix.Op.Index)
		return;

	auto type = getExpType(ctx.lp, postfix.child, ctx.current);
	if (type.nodeType == ir.NodeType.AAType) {
		auto aa = cast(ir.AAType)type;
		auto keyType = getExpType(ctx.lp, postfix.arguments[0], ctx.current);
		if(!isImplicitlyConvertable(keyType, aa.key) && !typesEqual(keyType, aa.key)) {
			throw makeBadImplicitCast(exp, keyType, aa.key);
		}
	}
}

void extypePostfix(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	rewriteSuperIfNeeded(exp, postfix, ctx.current, ctx.lp);
	extypePostfixIdentifier(ctx, exp, postfix);
	extypePostfixIndex(ctx, exp, postfix);
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
	if (handleNull(unary.type, unary.value, type) !is null) {
		exp = unary.value;
		return;
	}

	auto to = getClass(unary.type);
	auto from = getClass(type);

	if (to is null || from is null || to is from) {
		return;
	}

	auto fn = retrieveFunctionFromObject(ctx.lp, unary.location, "vrt_handle_cast");
	assert(fn !is null);

	auto fnref = buildExpReference(unary.location, fn, "vrt_handle_cast");
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

	for (size_t i = 0; i < _unary.argumentList.length; ++i) {
		extypeAssign(ctx, _unary.argumentList[i], fn.type.params[i]);
	}
}

void extypeUnary(Context ctx, ref ir.Exp exp, ir.Unary _unary)
{
	switch (_unary.op) with (ir.Unary.Op) {
	case Cast:
		return handleCastTo(ctx, exp, _unary);
	case New:
		return handleNew(ctx, exp, _unary);
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

	if (isIntegral(lprim) && isIntegral(rprim)) {
		bool leftUnsigned = isUnsigned(lprim.type);
		bool rightUnsigned = isUnsigned(rprim.type);
		if (leftUnsigned != rightUnsigned) {
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
				throw makeTypeIsNot(bin, rprim, lprim);
			}
		}
	}


	auto intsz = size(ir.PrimitiveType.Kind.Int);
	int largestsz;
	ir.Type largestType;

	if ((isFloatingPoint(lprim) && isFloatingPoint(rprim)) || (isIntegral(lprim) && isIntegral(rprim))) {
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
 * Handles logical operators (making a && b result in a bool),
 * binary of storage types, otherwise forwards to assign or primitive
 * specific functions.
 */
void extypeBinOp(Context ctx, ir.BinOp binop)
{
	auto ltype = realType(getExpType(ctx.lp, binop.left, ctx.current));
	auto rtype = realType(getExpType(ctx.lp, binop.right, ctx.current));

	if (handleIfNull(ctx, rtype, binop.left)) return;
	if (handleIfNull(ctx, ltype, binop.right)) return;

	switch(binop.op) with(ir.BinOp.Op) {
	case AddAssign, SubAssign, MulAssign, DivAssign, ModAssign, AndAssign,
	     OrAssign, XorAssign, CatAssign, LSAssign, SRSAssign, RSAssign, PowAssign, Assign:
		// TODO this needs to be changed if there is operator overloading
		auto asPostfix = cast(ir.Postfix)binop.left;
		if (asPostfix !is null) {
			auto postfixLeft = getExpType(ctx.lp, asPostfix.child, ctx.current);
			if (postfixLeft !is null &&
			    postfixLeft.nodeType == ir.NodeType.AAType &&
			    asPostfix.op == ir.Postfix.Op.Index) {
				auto aa = cast(ir.AAType)postfixLeft;

				auto valueType = getExpType(ctx.lp, binop.right, ctx.current);
				if(!isImplicitlyConvertable(valueType, aa.value) && !typesEqual(valueType, aa.value)) {
					throw makeBadImplicitCast(binop, valueType, aa.value);
				}
			}
		}
		break;
	default: break;
	}


	if (binop.op == ir.BinOp.Op.Assign) {
		if (effectivelyConst(ltype)) {
			throw makeCannotModify(binop, ltype);
		}

		extypeAssign(ctx, binop.right, ltype);

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

	if ((binop.op == ir.BinOp.Op.Cat || binop.op == ir.BinOp.Op.CatAssign) &&
	    ltype.nodeType == ir.NodeType.ArrayType) {
		if (binop.op == ir.BinOp.Op.CatAssign && effectivelyConst(ltype)) {
			throw makeCannotModify(binop, ltype);
		}
		extypeCat(binop, cast(ir.ArrayType)ltype, rtype);
		return;
	}

	if (ltype.nodeType == ir.NodeType.PrimitiveType && rtype.nodeType == ir.NodeType.PrimitiveType) {
		auto lprim = cast(ir.PrimitiveType) ltype;
		auto rprim = cast(ir.PrimitiveType) rtype;
		assert(lprim !is null && rprim !is null);
		extypeBinOp(ctx, binop, lprim, rprim);
	}

	if (ltype.nodeType == ir.NodeType.StorageType || rtype.nodeType == ir.NodeType.StorageType) {
		if (ltype.nodeType == ir.NodeType.StorageType) {
			binop.left = buildCastSmart(rtype, binop.left);
		} else {
			binop.right = buildCastSmart(ltype, binop.right);
		}
	}
}

/**
 * Ensure concatentation is sound.
 */
void extypeCat(ir.BinOp bin, ir.ArrayType left, ir.Type right)
{
	if (typesEqual(left, right) ||
	    typesEqual(right, left.base)) {
		return;
	}

	auto rarray = cast(ir.ArrayType) realType(right);
	if (rarray !is null && isImplicitlyConvertable(rarray.base, left.base) && (isConst(left.base) || isImmutable(left.base))) {
		return;
	}

	if (!isImplicitlyConvertable(right, left.base)) {
		throw makeBadImplicitCast(bin, right, left.base);
	}

	bin.right = buildCastSmart(left.base, bin.right);
}

void extypeTernary(Context ctx, ir.Ternary ternary)
{
	auto baseType = getExpType(ctx.lp, ternary.ifTrue, ctx.current);
	extypeAssign(ctx, ternary.ifFalse, baseType);

	auto condType = getExpType(ctx.lp, ternary.condition, ctx.current);
	if (!isBool(condType)) {
		ternary.condition = buildCastToBool(ternary.condition.location, ternary.condition);
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
		fn._body.statements.insertInPlace(index++, n);
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

	foreach (param; fn.params) {
		if (!param.hasBeenNested) {
			param.hasBeenNested = true;
			ensureResolved(ctx.lp, ctx.current, param.type);
			auto var = buildVariableSmart(param.location, param.type, ir.Variable.Storage.Field, param.name);
			addVarToStructSmart(ns, var);

			// Insert an assignment of the param to the nest struct.
			auto l = buildAccess(param.location, buildExpReference(np.location, np, np.name), param.name);
			auto r = buildExpReference(param.location, param, param.name);
			r.doNotRewriteAsNestedLookup = true;
			ir.Node n = buildExpStat(l.location, buildAssign(l.location, l, r));
			if (fn.nestedHiddenParameter !is null) {
				// Nested function.
				fn._body.statements = n ~ fn._body.statements;
			} else {
				// Parent function with nested children.
				fn._body.statements.insertInPlace(index++, n);
			}
		}
	}
}

/**
 * Ensure that a given switch statement is semantically sound.
 * Errors on bad final switches (doesn't cover all enum members, not on an enum at all),
 * and checks for doubled up cases.
 */
void verifySwitchStatement(Context ctx, ir.SwitchStatement ss)
{
	auto hashFunction = retrieveFunctionFromObject(ctx.lp, ss.location, "vrt_hash");

	auto conditionType = realType(getExpType(ctx.lp, ss.condition, ctx.current), false, true);
	auto originalCondition = ss.condition;
	if (isArray(conditionType)) {
		auto l = ss.location;
		auto asArray = cast(ir.ArrayType) conditionType;
		assert(asArray !is null);
		ir.Exp ptr = buildCastSmart(buildVoidPtr(l), buildAccess(l, copyExp(ss.condition), "ptr"));
		ir.Exp length = buildBinOp(l, ir.BinOp.Op.Mul, buildAccess(l, copyExp(ss.condition), "length"),
				buildAccess(l, buildTypeidSmart(l, asArray.base), "size"));
		ss.condition = buildCall(ss.condition.location, hashFunction, [ptr, length]);
		conditionType = buildUint(ss.condition.location);
	}

	struct ArrayCase
	{
		ir.Exp originalExp;
		ir.SwitchCase _case;
		ir.IfStatement lastIf;
	}
	ArrayCase[uint] arrayCases;
	size_t[] toRemove;  // Indices of cases that have been folded into a collision case.

	foreach (i, _case; ss.cases) {
		void replaceWithHashIfNeeded(ref ir.Exp exp) 
		{
			if (exp !is null) {
				auto etype = getExpType(ctx.lp, exp, ctx.current);
				if (isArray(etype)) {
					uint h;
					auto constant = cast(ir.Constant) exp;
					if (constant !is null) {
						assert(isString(etype));
						assert(constant._string[0] == '\"');
						assert(constant._string[$-1] == '\"');
						auto str = constant._string[1..$-1];
						h = hash(cast(void*) str.ptr, str.length * str[0].sizeof);
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
									sz = size(ss.location, ctx.lp, constant.type);
									assert(sz > 0);
								}
								switch (sz) {
								case 8:
									longArrayData ~= constant._ulong;
									break;
								default:
									intArrayData ~= constant._uint;
									break;
								}
								return;
							}
							auto cexp = cast(ir.Unary) e;
							if (cexp !is null) {
								assert(cexp.op == ir.Unary.Op.Cast);
								assert(sz == 0);
								sz = size(ss.location, ctx.lp, cexp.type);
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
							h = hash(longArrayData.ptr, longArrayData.length * ulong.sizeof);
						} else {
							h = hash(intArrayData.ptr, intArrayData.length * uint.sizeof);
						}
					}
					if (auto p = h in arrayCases) {
						auto aStatements = _case.statements.statements;
						auto bStatements = p._case.statements.statements;
						auto c = p._case.statements.myScope;
						auto aBlock = buildBlockStat(exp.location, p._case.statements, c, aStatements);
						auto bBlock = buildBlockStat(exp.location, p._case.statements, c, bStatements);
						p._case.statements.statements.length = 0;

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
						arrayCases[h] = ArrayCase(exp, _case, null);
					}
					exp = buildConstantUint(exp.location, h);
				}
			}
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
			extypeAssign(ctx, exp, conditionType);
		}
	}

	for (int i = cast(int) toRemove.length - 1; i >= 0; i--) {
		ss.cases = remove(ss.cases, toRemove[i]);
	}

	auto asEnum = cast(ir.Enum) conditionType;
	if (asEnum is null && ss.isFinal) {
		throw makeExpected(ss, "enum type for final switch");
	}
	if (ss.isFinal && ss.cases.length != asEnum.members.length) {
		throw makeFinalSwitchBadCoverage(ss);
	}
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
	bool enterFirstVariable;
	int nestedDepth;
	Context ctx;

public:
	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	/**
	 * For out of band checking of Variables.
	 */
	void transform(ir.Scope current, ir.Variable v)
	{
		ctx.setupFromScope(current);
		scope (exit) ctx.reset();

		this.enterFirstVariable = true;
		accept(v, this);
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

		ensureResolved(ctx.lp, ctx.current, ed.type);

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

	void resolve(ir.EnumDeclaration ed, ir.Exp prevExp)
	{
		ensureResolved(ctx.lp, ctx.current, ed.type);

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
		replaceStorageIfNeeded(ed.type);
		accept(ed.type, this);

		ed.resolved = true;
	}

	override void close()
	{
	}

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
		ctx.leave(s);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
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
		ctx.leave(c);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		ctx.lp.resolve(e);
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
		ensureResolved(ctx.lp, ctx.current, st);
		assert(st.isCanonical);
		return Continue;
	}

	override Status enter(ir.FunctionParam p)
	{
		ensureResolved(ctx.lp, ctx.current, p.type);
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		ctx.isVarAssign = true;
		scope (exit) ctx.isVarAssign = false;
		// This has to be done this way, because the order in
		// which the calls in this and the visiting functions
		// are exectuted matters.
		if (!enterFirstVariable) {
			v.hasBeenDeclared = true;
			ctx.lp.resolve(ctx.current, v);
			if (v.assign !is null) {
				rejectBadScopeAssign(ctx, v.assign, v.type);
			}
			return ContinueParent;
		}
		enterFirstVariable = true;

		ensureResolved(ctx.lp, ctx.current, v.type);

		bool inAggregate = (cast(ir.Aggregate) ctx.current.node) !is null;
		if (inAggregate && v.storage != ir.Variable.Storage.Local && v.storage != ir.Variable.Storage.Global) {
			if (v.assign !is null) {
				throw makeAssignToNonStaticField(v);
			}
			if (isConst(v.type) || isImmutable(v.type)) {
				throw makeConstField(v);
			}
		}

		replaceTypeOfIfNeeded(ctx, v.type);

		if (v.assign !is null) {
			acceptExp(v.assign, this);
			extypeAssign(ctx, v.assign, v.type);
		}

		replaceStorageIfNeeded(v.type);
		accept(v.type, this);

		return ContinueParent;
	}

	override Status enter(ir.Function fn)
	{
		if (fn.nestStruct !is null && fn.thisHiddenParameter !is null && !ctx.isFunction) {
			auto cvar = copyVariableSmart(fn.thisHiddenParameter.location, fn.thisHiddenParameter);
			addVarToStructSmart(fn.nestStruct, cvar);
		}
		handleNestedThis(fn);
		handleNestedParams(ctx, fn);
		ctx.lp.resolve(ctx.current, fn);
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


	override Status enter(ir.ReturnStatement ret)
	{
		auto fn = getParentFunction(ctx.current);
		if (fn is null) {
			throw panic(ret, "return statement outside of function.");
		}

		if (ret.exp !is null) {
			acceptExp(ret.exp, this);
			extypeAssign(ctx, ret.exp, fn.type.ret);
		}

		return ContinueParent;
	}

	override Status enter(ir.IfStatement ifs)
	{
		if (ifs.exp !is null) {
			acceptExp(ifs.exp, this);
			extypeCastToBool(ctx, ifs.exp);
		}

		if (ifs.thenState !is null) {
			accept(ifs.thenState, this);
		}

		if (ifs.elseState !is null) {
			accept(ifs.elseState, this);
		}

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
			extypeCastToBool(ctx, fs.test);
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
			extypeCastToBool(ctx, ws.condition);
		}

		accept(ws.block, this);

		return ContinueParent;
	}

	override Status enter(ir.DoStatement ds)
	{
		accept(ds.block, this);

		if (ds.condition !is null) {
			acceptExp(ds.condition, this);
			extypeCastToBool(ctx, ds.condition);
		}

		return ContinueParent;
	}

	override Status enter(ir.SwitchStatement ss)
	{
		verifySwitchStatement(ctx, ss);
		return Continue;
	}

	override Status leave(ir.ThrowStatement t)
	{
		extypeThrow(ctx, t);
		return Continue;
	}

	override Status enter(ir.AssertStatement as)
	{
		if (!as.isStatic) {
			throw panicUnhandled(as, "non static asserts");
		}
		auto cond = cast(ir.Constant) as.condition;
		auto msg = cast(ir.Constant) as.message;
		if ((cond is null || msg is null) || (!isBool(cond.type) || !isString(msg.type))) {
			throw panicUnhandled(as, "non simple static asserts (bool and string literal only).");
		}
		if (!cond._bool) {
			throw makeStaticAssert(as, msg._string);
		}
		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		ctx.enter(bs);
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
	enum Kind
	{
		Alias,
		Value,
		Type,
		Scope,
		Function,
		Template,
		EnumDeclaration,
		FunctionParam,
	}
	override Status enter(ref ir.Exp exp, ir.Typeid _typeid)
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
			_typeid.ident.length = 0;
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
		ensureResolved(ctx.lp, ctx.current, _typeid.type);
		replaceTypeOfIfNeeded(ctx, _typeid.type);
		return Continue;
	}


	/*
	 *
	 * Expressions.
	 *
	 */


	/// If this is an assignment to a @property function, turn it into a function call.
	override Status leave(ref ir.Exp e, ir.BinOp bin)
	{
		rewritePropertyFunctionAssign(ctx, e, bin);
		// If rewritten.
		if (e is bin) {
			extypeBinOp(ctx, bin);
		}
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.Postfix postfix)
	{
		extypePostfix(ctx, exp, postfix);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Postfix postfix)
	{
		extypeLeavePostfix(ctx, exp, postfix);
		return Continue;
	}


	override Status leave(ref ir.Exp exp, ir.Unary _unary)
	{
		if (_unary.type !is null) {
			ensureResolved(ctx.lp, ctx.current, _unary.type);
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
		ensureResolved(ctx.lp, ctx.current, te.type);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.VaArgExp vaexp)
	{
		ensureResolved(ctx.lp, ctx.current, vaexp.type);
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
		replaceExpReferenceIfNeeded(ctx, null, exp, eref);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.IdentifierExp ie)
	{
		extypeIdentifierExp(ctx, exp, ie);
		auto eref = cast(ir.ExpReference) exp;
		if (eref !is null) {
			replaceExpReferenceIfNeeded(ctx, null, exp, eref);
		}
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.TokenExp fexp)
	{
		if (fexp.type == ir.TokenExp.Type.File) {
			string fname = fexp.location.filename;
			version (Windows) {
				string[dchar] transTable = ['\\': "/"];
				fname = translate(fname, transTable);
			}
			exp = buildStringConstant(fexp.location, `"` ~ fname ~ `"`); 
			return Continue;
		} else if (fexp.type == ir.TokenExp.Type.Line) {
			exp = buildConstantInt(fexp.location, cast(int) fexp.location.line);
			return Continue;
		}

		char[] buf = `"`.dup;
		void sink(string s)
		{
			buf ~= s;
		}
		auto pp = new PrettyPrinter("\t", &sink);

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
			pp.transform(foundFunction.type.ret);
			buf ~= " ";
		}

		foreach_reverse (i, name; names) {
			buf ~= name ~ (i > 0 ? "." : "");
		}

		if (fexp.type == ir.TokenExp.Type.PrettyFunction) {
			buf ~= "(";
			foreach (i, ptype; ctx.currentFunction.type.params) {
				pp.transform(ptype);
				if (i < ctx.currentFunction.type.params.length - 1) {
					buf ~= ", ";
				}
			}
			buf ~= ")";
		}

		buf ~= "\"";

		exp = buildStringConstant(fexp.location, buf.idup);
		return Continue;
	}

public:
	this(LanguagePass lp)
	{
		ctx = new Context(lp);
		ctx.etyper = this;
	}
}
