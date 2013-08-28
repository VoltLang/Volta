// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.extyper;

import std.algorithm : remove;
import std.array : insertInPlace;
import std.conv : to;
import std.string : format;

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

struct AssignmentState
{
	LanguagePass lp;
	ir.Scope current;
	bool isVarAssign;
}

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
bool handleIfNull(LanguagePass lp, ir.Scope current, ir.Type left, ref ir.Exp right)
{
	auto rightType = getExpType(lp, right, current);
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
bool handleIfStructLiteral(ref AssignmentState state, ir.Type left, ref ir.Exp right)
{
	auto asLit = cast(ir.StructLiteral) right;
	if (asLit is null)
		return false;

	assert(asLit !is null);

	auto asStruct = cast(ir.Struct) realType(left);
	if (asStruct is null) {
		throw makeBadImplicitCast(right, getExpType(state.lp, right, state.current), left);
	}

	ir.Type[] types = getStructFieldTypes(asStruct);

	if (types.length < asLit.exps.length) {
		throw makeBadImplicitCast(right, getExpType(state.lp, right, state.current), left);
	}

	foreach (i, ref sexp; asLit.exps) {
		extypeAssign(state, sexp, types[i]);
	}

	asLit.type = buildTypeReference(right.location, asStruct, asStruct.name);
	return true;
}

/**
 * Implicitly convert PrimitiveTypes to bools for 'if' and friends.
 */
void extypeCastToBool(LanguagePass lp, ir.Scope current, ref ir.Exp exp)
{
	auto t = getExpType(lp, exp, current);
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
void extypeAssignHandleStorage(ref AssignmentState state, ref ir.Exp exp, ir.Type ltype)
{
	auto rtype = realType(getExpType(state.lp, exp, state.current));
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
void extypePassHandleStorage(ref AssignmentState state, ref ir.Exp exp, ir.Type ltype)
{
	auto rtype = realType(getExpType(state.lp, exp, state.current));
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
void rejectBadScopeAssign(ref AssignmentState state, ref ir.Exp exp, ir.Type type)
{
	auto storage = cast(ir.StorageType) realType(type);
	if (storage is null) {
		return;
	}
	if (mutableIndirection(storage.base)) {
		if (!state.isVarAssign || (state.current.node.nodeType != ir.NodeType.Function && state.current.node.nodeType != ir.NodeType.BlockStatement)) {
			throw makeBadImplicitCast(exp, type, storage);
		}
	}
}

/**
 * Implicitly convert to scope if possible.
 */
void extypeAssignStorageType(ref AssignmentState state, ref ir.Exp exp, ir.StorageType storage)
{
	auto type = realType(getExpType(state.lp, exp, state.current));
	if (storage.base is null) {
		if (type.nodeType == ir.NodeType.FunctionSetType) {
			auto fset = cast(ir.FunctionSetType) type;
			throw makeCannotDisambiguate(exp, fset.set.functions);

		}
		storage.base = copyTypeSmart(exp.location, type);
	}

	if (storage.type == ir.StorageType.Kind.Scope) {
		rejectBadScopeAssign(state, exp, storage);
		exp = buildCastSmart(storage.base, exp);
		extypeAssignDispatch(state, exp, storage.base);
	}

	if (canTransparentlyReferToBase(storage)) {
		extypeAssignDispatch(state, exp, storage.base);
	}
}

/**
 * Infer base types on storage types (eg 'auto a = 3').
 */
void extypePassStorageType(ref AssignmentState state, ref ir.Exp exp, ir.StorageType storage)
{
	auto type = getExpType(state.lp, exp, state.current);
	if (storage.base is null) {
		storage.base = copyTypeSmart(exp.location, type);
	}

	if (storage.type == ir.StorageType.Kind.Scope) {
		extypePassDispatch(state, exp, storage.base);
	} else if (canTransparentlyReferToBase(storage)) {
		extypePassDispatch(state, exp, storage.base);
	}
}

void extypeAssignTypeReference(ref AssignmentState state, ref ir.Exp exp, ir.TypeReference tr)
{
	extypeAssign(state, exp, tr.type);
}

/**
 * Handles implicit pointer casts. To void*, immutable(T)* to const(T)*
 * T* to const(T)* and the like.
 */
void extypeAssignPointerType(ref AssignmentState state, ref ir.Exp exp, ir.PointerType ptr)
{
	// string literals implicitly convert to typeof(string.ptr)
	auto constant = cast(ir.Constant) exp;
	if (constant !is null && constant._string.length != 0) {
		exp = buildAccess(exp.location, exp, "ptr");
	}

	auto type = realType(getExpType(state.lp, exp, state.current));

	auto storage = cast(ir.StorageType) type;
	if (storage !is null) {
		type = storage.base;
	}

	auto rp = cast(ir.PointerType) type;
	if (rp is null) {
		throw makeBadImplicitCast(exp, type, ptr);
	}

	if (typesEqual(ptr, rp)) {
		return;
	}

	if (ptr.base.nodeType == ir.NodeType.PrimitiveType) {
		auto asPrimitive = cast(ir.PrimitiveType) ptr.base;
		assert(asPrimitive !is null);
		if (asPrimitive.type == ir.PrimitiveType.Kind.Void) {
			exp = buildCastSmart(ptr, exp);
			return;
		}
	}

	if (isConst(ptr.base) && rp.base.nodeType != ir.NodeType.StorageType) {
		exp = buildCastSmart(ptr, exp);
		return;
	}

	if (isImmutable(rp.base) && isConst(ptr.base)) {
		exp = buildCastSmart(ptr, exp);
		return;
	}

	throw makeBadImplicitCast(exp, type, ptr);
}

/**
 * Implicit primitive casts (smaller to larger).
 */
void extypeAssignPrimitiveType(ref AssignmentState state, ref ir.Exp exp, ir.PrimitiveType lprim)
{
	auto rtype = getExpType(state.lp, exp, state.current);
	auto rprim = cast(ir.PrimitiveType) realType(rtype);
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
void extypeAssignClass(ref AssignmentState state, ref ir.Exp exp, ir.Class _class)
{
	auto type = realType(getExpType(state.lp, exp, state.current));
	assert(type !is null);

	auto rightClass = cast(ir.Class) type;
	if (rightClass is null) {
		throw makeBadImplicitCast(exp, type, _class);
	}
	state.lp.resolve(rightClass);

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

void extypeAssignEnum(ref AssignmentState state, ref ir.Exp exp, ir.Enum e)
{
	auto rtype = getExpType(state.lp, exp, state.current);
	if (typesEqual(e, rtype)) {
		return;
	}

	// TODO: This might need to be smarter.
	extypeAssignDispatch(state, exp, e.base);
}


/**
 * Handles assigning an overloaded function to a delegate.
 */
void extypeAssignCallableType(ref AssignmentState state, ref ir.Exp exp, ir.CallableType ctype)
{
	auto rtype = realType(getExpType(state.lp, exp, state.current));
	if (typesEqual(ctype, rtype)) {
		return;
	}
	if (rtype.nodeType == ir.NodeType.FunctionSetType) {
		auto fset = cast(ir.FunctionSetType) rtype;
		auto fn = selectFunction(state.lp, fset.set, ctype.params, exp.location);
		auto eRef = buildExpReference(exp.location, fn, fn.name);
		fset.set.reference = eRef;
		exp = eRef;
		replaceExpReferenceIfNeeded(state.lp, state.current, null, exp, eRef);
		extypeAssignCallableType(state, exp, ctype);
		return;
	}
	throw makeBadImplicitCast(exp, rtype, ctype);
}

/**
 * Handles casting arrays of non mutably indirect types with
 * differing storage types.
 */
void extypeAssignArrayType(ref AssignmentState state, ref ir.Exp exp, ir.ArrayType atype)
{
	auto rtype = realType(getExpType(state.lp, exp, state.current));
	if (typesEqual(atype, rtype)) {
		return;
	}

	auto rarr = cast(ir.ArrayType) rtype;
	if (atype !is null && rarr !is null) { 
		auto lstor = cast(ir.StorageType) atype.base;
		auto rstor = cast(ir.StorageType) rarr.base;
		if (lstor !is null && rstor is null) {
			if (typesEqual(lstor.base, rarr.base) && !mutableIndirection(lstor.base)) {
				return;
			}
		}
		if (rstor !is null && lstor is null) {
			if (typesEqual(rstor.base, atype.base) && !mutableIndirection(rstor.base)) {
				return;
			}
		}
		if (lstor !is null && rstor !is null && typesEqual(lstor.base, rstor.base) && !mutableIndirection(lstor.base)) {
			return;
		}
	}

	throw makeBadImplicitCast(exp, rtype, atype);
}

void extypeAssignAAType(ref AssignmentState state, ref ir.Exp exp, ir.AAType aatype)
{
	auto rtype = getExpType(state.lp, exp, state.current);
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

void extypeAssignDispatch(ref AssignmentState state, ref ir.Exp exp, ir.Type type)
{
	switch (type.nodeType) {
	case ir.NodeType.StorageType:
		auto storage = cast(ir.StorageType) type;
		extypeAssignStorageType(state, exp, storage);
		break;
	case ir.NodeType.TypeReference:
		auto tr = cast(ir.TypeReference) type;
		extypeAssignTypeReference(state, exp, tr);
		break;
	case ir.NodeType.PointerType:
		auto ptr = cast(ir.PointerType) type;
		extypeAssignPointerType(state, exp, ptr);
		break;
	case ir.NodeType.PrimitiveType:
		auto prim = cast(ir.PrimitiveType) type;
		extypeAssignPrimitiveType(state, exp, prim);
		break;
	case ir.NodeType.Class:
		auto _class = cast(ir.Class) type;
		extypeAssignClass(state, exp, _class);
		break;
	case ir.NodeType.Enum:
		auto e = cast(ir.Enum) type;
		extypeAssignEnum(state, exp, e);
		break;
	case ir.NodeType.FunctionType:
	case ir.NodeType.DelegateType:
		auto ctype = cast(ir.CallableType) type;
		extypeAssignCallableType(state, exp, ctype);
		break;
	case ir.NodeType.ArrayType:
		auto atype = cast(ir.ArrayType) type;
		extypeAssignArrayType(state, exp, atype);
		break;
	case ir.NodeType.AAType:
		auto aatype = cast(ir.AAType) type;
		extypeAssignAAType(state, exp, aatype);
		break;
	case ir.NodeType.Struct:
	case ir.NodeType.Union:
		auto rtype = getExpType(state.lp, exp, state.current);
		if (typesEqual(type, rtype)) {
			return;
		}
		throw makeBadImplicitCast(exp, rtype, type);
	default:
		throw panicUnhandled(exp, to!string(type.nodeType));
	}
}


void extypePassDispatch(ref AssignmentState state, ref ir.Exp exp, ir.Type type)
{
	switch (type.nodeType) {
	case ir.NodeType.StorageType:
		auto storage = cast(ir.StorageType) type;
		extypePassStorageType(state, exp, storage);
		break;
	default:
		extypeAssignDispatch(state, exp, type);
		break;
	}
}

void extypePass(ref AssignmentState state, ref ir.Exp exp, ir.Type type)
{
	ensureResolved(state.lp, state.current, type);
	if (handleIfStructLiteral(state, type, exp)) return;
	if (handleIfNull(state.lp, state.current, type, exp)) return;

	extypePassHandleStorage(state, exp, type);

	extypePassDispatch(state, exp, type);
}

void extypeAssign(ref AssignmentState state, ref ir.Exp exp, ir.Type type)
{
	ensureResolved(state.lp, state.current, type);
	if (handleIfStructLiteral(state, type, exp)) return;
	if (handleIfNull(state.lp, state.current, type, exp)) return;

	extypeAssignHandleStorage(state, exp, type);

	extypeAssignDispatch(state, exp, type);
}

/**
 * Replace IdentifierExps with ExpReferences.
 */
void extypeIdentifierExp(ir.Function[] functionStack, LanguagePass lp, ir.Scope current, ref ir.Exp e, ir.IdentifierExp i)
{
	if (i.type is null) {
		if (i.globalLookup) {
			i.type = declTypeLookup(i.location, lp, getModuleFromScope(current).myScope, i.value);
		} else {
			i.type = declTypeLookup(i.location, lp, current, i.value);
		}
	}

	auto store = lookup(lp, current, i.location, i.value);
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
		tagNestedVariables(current, functionStack, var, i, store, e);
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
void extypeLeavePostfix(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Postfix postfix)
{
	ir.Postfix[] postfixes;
	ir.Postfix currentPostfix = postfix;
	do {
		postfixes ~= currentPostfix;
		currentPostfix = cast(ir.Postfix) currentPostfix.child;
	} while (currentPostfix !is null);

	if (postfix.op != ir.Postfix.Op.Call) {
		auto type = getExpType(lp, postfix.child, current);
		/* If we end up with a identifier postfix that points
		 * at a struct, and retrieves a member function, then
		 * transform the op from Identifier to CreatePostfix.
		 */
		if (postfix.identifier !is null) {
			auto asStorage = cast(ir.StorageType) realType(type);
			if (asStorage !is null && canTransparentlyReferToBase(asStorage)) {
				type = asStorage.base;
			}

			if (type.nodeType != ir.NodeType.Struct &&
			    type.nodeType != ir.NodeType.Union &&
			    type.nodeType != ir.NodeType.Class) {
				return;
			}

			/// @todo this is probably an error.
			auto aggScope = getScopeFromType(type);
			auto store = lookupAsThisScope(lp, aggScope, postfix.location, postfix.identifier.value);
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

		propertyToCallIfNeeded(postfix.location, lp, exp, current, postfixes);

		return;
	}

	auto type = getExpType(lp, postfix.child, current);
	bool thisCall;

	ir.CallableType asFunctionType;
	auto asFunctionSet = cast(ir.FunctionSetType) realType(type);
	if (asFunctionSet !is null) {
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

		asFunctionSet.set.reference = eref;
		auto fn = selectFunction(lp, current, asFunctionSet.set, postfix.arguments, postfix.location);
		eref.decl = fn;
		asFunctionType = fn.type;

		if (reeval) {
			replaceExpReferenceIfNeeded(lp, current, null, postfix.child, eref);
		}
	} else {
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
					auto eref = cast(ir.ExpReference) postfix.child;
					assert(eref !is null);
					auto fn = selectFunction(lp, current, _class.userConstructors, postfix.arguments, postfix.location);
					asFunctionType = fn.type;
					eref.decl = fn;
					thisCall = true;
				} else {
					throw makeBadCall(postfix, type);
				}
			}
		}
	}

	if (asFunctionType.isScope && postfix.child.nodeType == ir.NodeType.Postfix) {
		auto asPostfix = cast(ir.Postfix) postfix.child;
		auto parentType = getExpType(lp, asPostfix.child, current);
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
		auto funcNumArgs = asFunctionType.params.length - 1;
		if (callNumArgs < funcNumArgs) {
			throw makeWrongNumberOfArguments(postfix, callNumArgs, funcNumArgs);
		}
		auto amountOfVarArgs = callNumArgs - funcNumArgs;
		auto argsSlice = postfix.arguments[0 .. funcNumArgs];
		auto varArgsSlice = postfix.arguments[funcNumArgs .. $];

		auto tinfoClass = retrieveTypeInfo(lp, current, postfix.location);
		auto tr = buildTypeReference(postfix.location, tinfoClass, tinfoClass.name);
		tr.location = postfix.location;
		auto array = new ir.ArrayType();
		array.location = postfix.location;
		array.base = tr;

		auto typeidsLiteral = new ir.ArrayLiteral();
		typeidsLiteral.location = postfix.location;
		typeidsLiteral.type = array;

		foreach (_exp; varArgsSlice) {
			auto typeId = new ir.Typeid();
			typeId.location = postfix.location;
			typeId.type = copyTypeSmart(postfix.location, getExpType(lp, _exp, current));
			typeidsLiteral.values ~= typeId;
		}

		postfix.arguments = argsSlice ~ typeidsLiteral ~ varArgsSlice;
	}

	if (!asFunctionType.hasVarArgs &&
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
		auto state = AssignmentState(lp, current, false);
		extypePass(state, postfix.arguments[i], asFunctionType.params[i]);
	}

	if (thisCall) {
		// Explicit constructor call.
		auto tvar = getThisVar(postfix.location, lp, current);
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
 * Even tho FunctionSets might need rewriting they are not rewritten
 * directly but instead this function is called after they have been
 * rewritten and the ExpReference has been resolved to a single Function.
 */
bool replaceExpReferenceIfNeeded(LanguagePass lp, ir.Scope current,
                                 ir.Type referredType, ref ir.Exp exp, ir.ExpReference eRef)
{
	// Hold onto your hats because this is ugly!
	// But this needs to be run after this function has early out
	// or rewritten the lookup.
	scope (success) {
		propertyToCallIfNeeded(exp.location, lp, exp, current, null);
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

	auto thisVar = getThisVar(eRef.location, lp, current);
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
	auto store = lookupOnlyThisScope(lp, expressionAgg.myScope, exp.location, ident);
	if (store !is null && store.node !is eRef.decl) {
		if (eRef.decl.nodeType !is ir.NodeType.FunctionParam) {
			throw makeNotMember(eRef, expressionAgg, ident);
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
void rewritePropertyFunctionAssign(LanguagePass lp, ir.Scope current, ref ir.Exp e, ir.BinOp bin)
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
		auto functionStore = lookupOnlyThisScope(lp, asClass.myScope, bin.location, functionName);
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
void extypeTypeLookup(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Postfix[] postfixIdents, ir.Type type)
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
		if (lp.settings.isVersionSet("V_LP64")) {
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
void extypePostfixIdentifier(LanguagePass lp, ir.Function[] functionStack, ir.Scope current, ref ir.Exp exp, ir.Postfix postfix)
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
			extypeTypeLookup(lp, current, exp, postfixIdents, typeExp.type);
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
			tagNestedVariables(current, functionStack, var, firstExp, store, exp);
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
	// postfix is in an unknown state at this point.
	{
		_scope = current;
		loc = identExp.location;
		ident = identExp.value;
		idents = [ident];

		/// @todo handle leading dot.
		assert(!identExp.globalLookup);

		store = lookup(lp, _scope, loc, ident);
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
				extypeTypeLookup(lp, current, exp, postfixIdents, prim);
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

			store = lookupOnlyThisScope(lp, _scope, loc, ident);
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
		replaceExpReferenceIfNeeded(lp, current, lastType, exp, _ref);
	} else {
		postfix = postfixIdents[0];
		postfix.child = _ref;
		replaceExpReferenceIfNeeded(lp, current, lastType, postfix.child, _ref);
	}
}

void extypePostfixIndex(LanguagePass lp, ir.Function[] functionStack, ir.Scope current, ref ir.Exp exp, ir.Postfix postfix)
{
	if (postfix.op != ir.Postfix.Op.Index)
		return;

	auto type = getExpType(lp, postfix.child, current);
	if (type.nodeType == ir.NodeType.AAType) {
		auto aa = cast(ir.AAType)type;
		auto keyType = getExpType(lp, postfix.arguments[0], current);
		if(!isImplicitlyConvertable(keyType, aa.key) && !typesEqual(keyType, aa.key)) {
			throw makeBadImplicitCast(exp, keyType, aa.key);
		}
	}
}

void extypePostfix(LanguagePass lp, ir.Function[] functionStack, ir.Scope current, ref ir.Exp exp, ir.Postfix postfix)
{
	rewriteSuperIfNeeded(exp, postfix, current, lp);
	extypePostfixIdentifier(lp, functionStack, current, exp, postfix);
	extypePostfixIndex(lp, functionStack, current, exp, postfix);
}

/**
 * Stops casting to an overloaded function name, casting from null, and wires
 * up some runtime magic needed for classes.
 */
void handleCastTo(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Unary unary)
{
	assert(unary.type !is null);
	assert(unary.value !is null);

	auto type = realType(getExpType(lp, unary.value, current));
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

	auto fn = retrieveFunctionFromObject(lp, from.myScope, unary.location, "vrt_handle_cast");
	assert(fn !is null);

	auto fnref = buildExpReference(unary.location, fn, "vrt_handle_cast");
	auto tid = buildTypeidSmart(unary.location, to);
	auto val = buildCastToVoidPtr(unary.location, unary.value);
	unary.value = buildCall(unary.location, fnref, [val, cast(ir.Exp)tid]);
}

/**
 * Type new expressions.
 */
void handleNew(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Unary _unary)
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
	lp.actualize(_class);

	auto fn = selectFunction(lp, current, _class.userConstructors, _unary.argumentList, _unary.location);

	lp.resolve(current, fn);

	for (size_t i = 0; i < _unary.argumentList.length; ++i) {
		auto state = AssignmentState(lp, current, false);
		extypeAssign(state, _unary.argumentList[i], fn.type.params[i]);
	}
}

void extypeUnary(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Unary _unary)
{
	switch (_unary.op) with (ir.Unary.Op) {
	case Cast:
		return handleCastTo(lp, current, exp, _unary);
	case New:
		return handleNew(lp, current, exp, _unary);
	default:
	}
}

/**
 * Everyone's favourite: integer promotion! :D!
 * In general, converts to the largest type needed in a binary expression.
 */
void extypeBinOp(LanguagePass lp, ir.Scope current, ir.BinOp bin, ir.PrimitiveType lprim, ir.PrimitiveType rprim)
{
	auto leftsz = size(lprim.type);
	auto rightsz = size(rprim.type);

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
void extypeBinOp(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto ltype = realType(getExpType(lp, binop.left, current));
	auto rtype = realType(getExpType(lp, binop.right, current));

	if (handleIfNull(lp, current, rtype, binop.left)) return;
	if (handleIfNull(lp, current, ltype, binop.right)) return;

	switch(binop.op) with(ir.BinOp.Op) {
	case AddAssign, SubAssign, MulAssign, DivAssign, ModAssign, AndAssign,
	     OrAssign, XorAssign, CatAssign, LSAssign, SRSAssign, RSAssign, PowAssign:
	case Assign:
		// TODO this needs to be changed if there is operator overloading
		auto asPostfix = cast(ir.Postfix)binop.left;
		if (asPostfix !is null) {
			auto postfixLeft = getExpType(lp, asPostfix.child, current);
			if (postfixLeft !is null &&
			    postfixLeft.nodeType == ir.NodeType.AAType &&
			    asPostfix.op == ir.Postfix.Op.Index) {
				auto aa = cast(ir.AAType)postfixLeft;

				auto valueType = getExpType(lp, binop.right, current);
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

		auto state = AssignmentState(lp, current, false);
		extypeAssign(state, binop.right, ltype);

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
		extypeBinOp(lp, current, binop, lprim, rprim);
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

void extypeTernary(ref AssignmentState state, ir.Ternary ternary)
{
	auto baseType = getExpType(state.lp, ternary.ifTrue, state.current);
	extypeAssign(state, ternary.ifFalse, baseType);

	auto condType = getExpType(state.lp, ternary.condition, state.current);
	if (!isBool(condType)) {
		ternary.condition = buildCastToBool(ternary.condition.location, ternary.condition);
	}
}

/// Replace TypeOf with its expression's type, if needed.
void replaceTypeOfIfNeeded(LanguagePass lp, ir.Scope current, ref ir.Type type)
{
	auto asTypeOf = cast(ir.TypeOf) realType(type);
	if (asTypeOf is null) {
		assert(type.nodeType != ir.NodeType.TypeOf);
		return;
	}

	type = copyTypeSmart(asTypeOf.location, getExpType(lp, asTypeOf.exp, current));
}

/**
 * Ensure that a thrown type inherits from Throwable.
 */
void extypeThrow(LanguagePass lp, ir.Scope current, ir.ThrowStatement t)
{
	auto throwable = cast(ir.Class) retrieveTypeFromObject(lp, current, t.location, "Throwable");
	assert(throwable !is null);

	auto type = getExpType(lp, t.exp, current);
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
void handleNestedParams(LanguagePass lp, ir.Scope current, ir.Function fn)
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
			ensureResolved(lp, current, param.type);
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
void verifySwitchStatement(LanguagePass lp, ir.Scope current, ir.SwitchStatement ss)
{
	auto hashFunction = retrieveFunctionFromObject(lp, current, ss.location, "vrt_hash");

	auto conditionType = realType(getExpType(lp, ss.condition, current), false, true);
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
	auto astate = AssignmentState(lp, current, false);

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
				auto etype = getExpType(lp, exp, current);
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
									sz = size(ss.location, lp, constant.type);
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
								sz = size(ss.location, lp, cexp.type);
								assert(sz == 8);
								addExp(cexp.value);
								return;
							}

							auto type = getExpType(lp, exp, current);
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
			extypeAssign(astate, _case.firstExp, conditionType);
		}
		if (_case.secondExp !is null) {
			replaceWithHashIfNeeded(_case.secondExp);
			extypeAssign(astate, _case.secondExp, conditionType);
		}
		foreach (ref exp; _case.exps) {
			extypeAssign(astate, exp, conditionType);
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
class ExTyper : ScopeManager, Pass
{
public:
	LanguagePass lp;
	bool enterFirstVariable;
	int nestedDepth;

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
		assert(this.current is null);
		this.current = current;
		scope (exit) {
			this.current = null;
		}

		this.enterFirstVariable = true;
		accept(v, this);
	}

	/**
	 * For out of band checking of UserAttributes.
	 */
	void transform(ir.Scope current, ir.Attribute a)
	{
		assert(this.current is null);
		this.current = current;
		scope (exit) {
			this.current = null;
		}

		basicValidateUserAttribute(lp, current, a);

		auto ua = a.userAttribute;
		assert(ua !is null);

		foreach (i, ref arg; a.arguments) {
			auto state = AssignmentState(lp, current, false);
			extypeAssign(state, a.arguments[i], ua.fields[i].type);
			acceptExp(a.arguments[i], this);
		}
	}

	void transform(ir.Scope current, ir.EnumDeclaration ed)
	{
		if (ed.resolved) {
			return;
		}

		assert(this.current is null);
		this.current = current;
		scope (exit) {
			this.current = null;
		}

		ensureResolved(lp, current, ed.type);

		ir.EnumDeclaration[] edStack;
		ir.Exp prevExp;

		do {
			edStack ~= ed;
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
		ensureResolved(lp, current, ed.type);

		if (ed.assign is null) {
			if (prevExp is null) {
				ed.assign = buildConstantInt(ed.location, 0);
			} else {
				auto loc = ed.location;
				auto prevType = getExpType(lp, prevExp, current);
				if (!isIntegral(prevType)) {
					throw makeTypeIsNot(ed, prevType, buildInt(ed.location));
				}

				ed.assign = evaluate(lp, current, buildAdd(loc, copyExp(prevExp), buildConstantInt(loc, 1)));
			}
		} else {
			acceptExp(ed.assign, this);
			if (needsEvaluation(ed.assign)) {
				ed.assign = evaluate(lp, current, ed.assign);
			}
		}

		auto state = AssignmentState(lp, current, false);
		extypeAssign(state, ed.assign, ed.type);
		replaceStorageIfNeeded(ed.type);
		accept(ed.type, this);

		ed.resolved = true;
	}

	override void close()
	{
	}

	override Status enter(ir.Alias a)
	{
		lp.resolve(a);
		return ContinueParent;
	}

	override Status enter(ir.Struct s)
	{
		lp.actualize(s);
		super.enter(s);
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		lp.actualize(u);
		super.enter(u);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		lp.actualize(c);
		super.enter(c);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		lp.resolve(e);
		super.enter(e);
		return Continue;
	}

	override Status enter(ir.UserAttribute ua)
	{
		lp.actualize(ua);
		// Everything is done by actualize.
		return ContinueParent;
	}

	override Status enter(ir.EnumDeclaration ed)
	{
		lp.resolve(current, ed);
		return ContinueParent;
	}

	override Status enter(ir.StorageType st)
	{
		ensureResolved(lp, current, st);
		assert(st.isCanonical);
		return Continue;
	}

	override Status enter(ir.FunctionParam p)
	{
		ensureResolved(lp, current, p.type);
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		// This has to be done this way, because the order in
		// which the calls in this and the visiting functions
		// are exectuted matters.
		if (!enterFirstVariable) {
			v.hasBeenDeclared = true;
			lp.resolve(current, v);
			if (v.assign !is null) {
				auto state = AssignmentState(lp, current, true);
				rejectBadScopeAssign(state, v.assign, v.type);
			}
			return ContinueParent;
		}
		enterFirstVariable = true;

		ensureResolved(lp, current, v.type);

		bool inAggregate = (cast(ir.Aggregate) current.node) !is null;
		if (inAggregate && v.storage != ir.Variable.Storage.Local && v.storage != ir.Variable.Storage.Global) {
			if (v.assign !is null) {
				throw makeAssignToNonStaticField(v);
			}
			if (isConst(v.type) || isImmutable(v.type)) {
				throw makeConstField(v);
			}
		}

		replaceTypeOfIfNeeded(lp, current, v.type);

		if (v.assign !is null) {
			acceptExp(v.assign, this);
			auto state = AssignmentState(lp, current, true);
			extypeAssign(state, v.assign, v.type);
		}

		replaceStorageIfNeeded(v.type);
		accept(v.type, this);

		return ContinueParent;
	}

	override Status enter(ir.Function fn)
	{
		if (fn.nestStruct !is null && fn.thisHiddenParameter !is null && functionStack.length == 0) {
			auto cvar = copyVariableSmart(fn.thisHiddenParameter.location, fn.thisHiddenParameter);
			addVarToStructSmart(fn.nestStruct, cvar);
		}
		handleNestedThis(fn);
		handleNestedParams(lp, current, fn);
		lp.resolve(current, fn);
		super.enter(fn);
		return Continue;
	}

	/*
	 *
	 * Statements.
	 *
	 */


	override Status enter(ir.ReturnStatement ret)
	{
		auto fn = getParentFunction(current);
		if (fn is null) {
			throw panic(ret, "return statement outside of function.");
		}

		if (ret.exp !is null) {
			acceptExp(ret.exp, this);
			auto state = AssignmentState(lp, current, false);
			extypeAssign(state, ret.exp, fn.type.ret);
		}

		return ContinueParent;
	}

	override Status enter(ir.IfStatement ifs)
	{
		if (ifs.exp !is null) {
			acceptExp(ifs.exp, this);
			extypeCastToBool(lp, current, ifs.exp);
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
		super.enter(fs.block);
		foreach (i; fs.initVars) {
			accept(i, this);
		}
		foreach (ref i; fs.initExps) {
			acceptExp(i, this);
		}

		if (fs.test !is null) {
			acceptExp(fs.test, this);
			extypeCastToBool(lp, current, fs.test);
		}
		foreach (ref increment; fs.increments) {
			acceptExp(increment, this);
		}
		foreach (statement; fs.block.statements) {
			accept(statement, this);
		}
		super.leave(fs.block);

		return ContinueParent;
	}

	override Status enter(ir.WhileStatement ws)
	{
		if (ws.condition !is null) {
			acceptExp(ws.condition, this);
			extypeCastToBool(lp, current, ws.condition);
		}

		accept(ws.block, this);

		return ContinueParent;
	}

	override Status enter(ir.DoStatement ds)
	{
		accept(ds.block, this);

		if (ds.condition !is null) {
			acceptExp(ds.condition, this);
			extypeCastToBool(lp, current, ds.condition);
		}

		return ContinueParent;
	}

	override Status enter(ir.SwitchStatement ss)
	{
		verifySwitchStatement(lp, current, ss);
		return Continue;
	}

	override Status leave(ir.ThrowStatement t)
	{
		extypeThrow(lp, current, t);
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


	/*
	 *
	 * Types.
	 *
	 */


	override Status enter(ir.FunctionType ftype)
	{
		replaceTypeOfIfNeeded(lp, current, ftype.ret);
		return Continue;
	}

	override Status enter(ir.DelegateType dtype)
	{
		replaceTypeOfIfNeeded(lp, current, dtype.ret);
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
			auto store = lookup(lp, current, _typeid.location, _typeid.ident);
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
			_typeid.type = getExpType(lp, _typeid.exp, current);
			if ((cast(ir.Aggregate) _typeid.type) !is null) {
				_typeid.type = buildTypeReference(_typeid.type.location, _typeid.type);
			} else {
				_typeid.type = copyType(_typeid.type);
			}
			_typeid.exp = null;
		}
		ensureResolved(lp, current, _typeid.type);
		replaceTypeOfIfNeeded(lp, current, _typeid.type);
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
		rewritePropertyFunctionAssign(lp, current, e, bin);
		// If rewritten.
		if (e is bin) {
			extypeBinOp(lp, current, bin);
		}
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.Postfix postfix)
	{
		extypePostfix(lp, functionStack, current, exp, postfix);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Postfix postfix)
	{
		extypeLeavePostfix(lp, current, exp, postfix);
		return Continue;
	}


	override Status leave(ref ir.Exp exp, ir.Unary _unary)
	{
		if (_unary.type !is null) {
			ensureResolved(lp, current, _unary.type);
			replaceTypeOfIfNeeded(lp, current, _unary.type);
		}
		extypeUnary(lp, current, exp, _unary);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Ternary ternary)
	{
		auto state = AssignmentState(lp, current, false);
		extypeTernary(state, ternary);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.TypeExp te)
	{
		ensureResolved(lp, current, te.type);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.ExpReference eref)
	{
		replaceExpReferenceIfNeeded(lp, current, null, exp, eref);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.IdentifierExp ie)
	{
		extypeIdentifierExp(functionStack, lp, current, exp, ie);
		auto eref = cast(ir.ExpReference) exp;
		if (eref !is null) {
			replaceExpReferenceIfNeeded(lp, current, null, exp, eref);
		}
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.TokenExp fexp)
	{
		if (fexp.type == ir.TokenExp.Type.File) {
			exp = buildStringConstant(fexp.location, `"` ~ fexp.location.filename ~ `"`); 
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
		ir.Scope scop = current;
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
			foreach (i, ptype; functionStack[$-1].type.params) {
				pp.transform(ptype);
				if (i < functionStack[$-1].type.params.length - 1) {
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
		this.lp = lp;
	}
}
