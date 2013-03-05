// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.extyper;

import std.conv : to;
import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.expreplace;
import volt.visitor.scopemanager;
import volt.semantic.classify;
import volt.semantic.classresolver;
import volt.semantic.lookup;
import volt.semantic.typer;
import volt.semantic.util;


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
bool handleNull(LanguagePass lp, ir.Scope current, ref ir.Exp right, ir.Type left)
{
	auto rightType = getExpType(lp, right, current);
	if (rightType.nodeType != ir.NodeType.NullType) {
		return false;
	}

	auto constant = cast(ir.Constant) right;
	if (constant is null) {
		throw CompilerPanic(right.location, "non constant null");
	}

	while (true) {
		switch (left.nodeType) with (ir.NodeType) {
		case PointerType:
			constant.type = buildVoidPtr(right.location);
			right = buildCastSmart(right.location, left, right);
			return true;
		case ArrayType:
			right = buildArrayLiteralSmart(right.location, left);
			return true;
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
				return true;
			}
			goto default;
		default:
			string emsg = format("can't convert null into '%s'.", to!string(left.nodeType));
			throw new CompilerError(right.location, emsg);
		}
	}
	return true;
}

/**
 * This handles implicitly typing a struct literal.
 *
 * While generic currently only used by extypeAssign.
 */
bool handleStructLiteral(LanguagePass lp, ir.Scope current, ref ir.Exp right, ir.Type left)
{
	auto asLit = cast(ir.StructLiteral) right;
	if (asLit is null)
		return false;

	assert(asLit !is null);
	string emsg = "cannot implicitly cast struct literal to destination.";

	auto asStruct = cast(ir.Struct) left;
	if (asStruct is null) {
		auto asTR = cast(ir.TypeReference) left;
		if (asTR !is null) {
			asStruct = cast(ir.Struct) asTR.type;
		}
		if (asStruct is null) {
			throw new CompilerError(right.location, emsg);
		}
	}

	ir.Type[] types = getStructFieldTypes(asStruct);

	if (types.length < asLit.exps.length) {
		throw new CompilerError(right.location, "cannot implicitly cast struct literal -- too many expressions for target.");
	}

	foreach (i, ref sexp; asLit.exps) {
		extypeAssign(lp, current, sexp, types[i]);
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
		auto asPrimitive = cast(ir.PrimitiveType) t;
		if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
			return;
		}
	}
	exp = buildCastToBool(exp.location, exp);
}

/**
 * This handles the exp being storage.
 */
void extypeAssignHandleStorage(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Type ltype)
{
	auto rtype = getExpType(lp, exp, current);
	if (ltype.nodeType != ir.NodeType.StorageType &&
	    rtype.nodeType == ir.NodeType.StorageType) {
		auto asStorageType = cast(ir.StorageType) rtype;
		assert(asStorageType !is null);
		if (asStorageType.type == ir.StorageType.Kind.Scope) {
			if (mutableIndirection(asStorageType.base)) {
				throw new CompilerError(exp.location, "cannot assign to scoped variable.");
			}
			exp = buildCastSmart(asStorageType.base, exp);
		}

		if (effectivelyConst(rtype)) {
			if (!mutableIndirection(asStorageType.base)) {
				exp = buildCastSmart(asStorageType.base, exp);
			} else {
				throw new CompilerError(exp.location, "cannot implicitly convert const to non const.");
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

void extypePassHandleStorage(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Type ltype)
{
	auto rtype = getExpType(lp, exp, current);
	if (ltype.nodeType != ir.NodeType.StorageType &&
	    rtype.nodeType == ir.NodeType.StorageType) {
		auto asStorageType = cast(ir.StorageType) rtype;
		assert(asStorageType !is null);

		if (effectivelyConst(rtype)) {
			if (!mutableIndirection(asStorageType.base)) {
				exp = buildCastSmart(asStorageType.base, exp);
			} else {
				throw new CompilerError(exp.location, "cannot implicitly convert const to non const.");
			}
		}
	}
}

void extypeAssignStorageType(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.StorageType storage)
{
	auto type = getExpType(lp, exp, current);
	if (storage.base is null) {
		storage.base = copyTypeSmart(exp.location, type);
	}

	if (storage.type == ir.StorageType.Kind.Scope) {
		if (mutableIndirection(storage.base)) {
			throw new CompilerError(exp.location, "cannot convert scope into mutably indirectable type.");
		}
		exp = buildCastSmart(storage.base, exp);
		extypeAssignDispatch(lp, current, exp, storage.base);
	}

	if (canTransparentlyReferToBase(storage)) {
		extypeAssignDispatch(lp, current, exp, storage.base);
	}
}

void extypePassStorageType(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.StorageType storage)
{
	auto type = getExpType(lp, exp, current);
	if (storage.base is null) {
		storage.base = copyTypeSmart(exp.location, type);
	}

	if (storage.type == ir.StorageType.Kind.Scope) {
		extypePassDispatch(lp, current, exp, storage.base);
	} else if (canTransparentlyReferToBase(storage)) {
		extypePassDispatch(lp, current, exp, storage.base);
	}
}

void extypeAssignTypeReference(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.TypeReference tr)
{
	extypeAssign(lp, current, exp, tr.type);
}

void extypeAssignPointerType(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.PointerType ptr)
{
	auto type = getExpType(lp, exp, current);

	auto storage = cast(ir.StorageType) type;
	if (storage !is null) {
		type = storage.base;
	}

	auto rp = cast(ir.PointerType) type;
	if (rp is null) {
		throw new CompilerError(exp.location, "cannot implicitly convert expression into a pointer.");
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

	throw new CompilerError(exp.location, "pointers may only be implicitly converted to void*.");
}

void extypeAssignPrimitiveType(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.PrimitiveType lprim)
{
	auto rprim = cast(ir.PrimitiveType) getExpType(lp, exp, current);
	if (rprim is null) {
		throw new CompilerError(exp.location, "trying to convert non primitive type into primitive type.");
	}

	if (typesEqual(lprim, rprim)) {
		return;
	}

	auto lsize = size(lprim.type);
	auto rsize = size(rprim.type);

	auto lunsigned = isUnsigned(lprim.type);
	auto runsigned = isUnsigned(rprim.type);

	if (lunsigned != runsigned && !fitsInPrimitive(lprim, exp) && rsize >= lsize) {
		throw new CompilerError(exp.location, "cannot implicitly convert expression to destination type.");
	}

	if (rsize > lsize && !fitsInPrimitive(lprim, exp)) {
		throw new CompilerError(exp.location, format("cannot implicitly cast '%s' to '%s'.", to!string(rprim.type), to!string(lprim.type)));
	}

	exp = buildCastSmart(lprim, exp);
}

void extypeAssignClass(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Class _class)
{
	auto type = getExpType(lp, exp, current);
	assert(type !is null);

	auto rightClass = cast(ir.Class) type;
	if (rightClass is null) {
		auto str = format("cannot assign non-class '%s' to class '%s'",
		                  to!string(type.nodeType), _class.name);
		throw new CompilerError(exp.location, str);
	}
	lp.resolve(rightClass);

	/// Check for converting child classes into parent classes.
	if (_class !is null && rightClass !is null) {
		if (inheritsFrom(rightClass, _class)) {
			exp = buildCastSmart(exp.location, _class, exp);
			return;
		}
	}

	if (_class !is rightClass) {
		throw new CompilerError(exp.location, format("cannot convert class '%s' to class '%s'", rightClass.name, _class.name));
	}
}

void extypeAssignDispatch(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Type type)
{
	switch (type.nodeType) {
	case ir.NodeType.StorageType:
		auto storage = cast(ir.StorageType) type;
		extypeAssignStorageType(lp, current, exp, storage);
		break;
	case ir.NodeType.TypeReference:
		auto tr = cast(ir.TypeReference) type;
		extypeAssignTypeReference(lp, current, exp, tr);
		break;
	case ir.NodeType.PointerType:
		auto ptr = cast(ir.PointerType) type;
		extypeAssignPointerType(lp, current, exp, ptr);
		break;
	case ir.NodeType.PrimitiveType:
		auto prim = cast(ir.PrimitiveType) type;
		extypeAssignPrimitiveType(lp, current, exp, prim);
		break;
	case ir.NodeType.Class:
		auto _class = cast(ir.Class) type;
		extypeAssignClass(lp, current, exp, _class);
		break;
	case ir.NodeType.ArrayType:
	case ir.NodeType.FunctionType:
	case ir.NodeType.DelegateType:
	case ir.NodeType.Struct:
		break;
	default:
		string emsg = format("unhandled extypeAssign type '%s'", to!string(type.nodeType));
		throw CompilerPanic(exp.location, emsg);
	}
}


void extypePassDispatch(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Type type)
{
	switch (type.nodeType) {
	case ir.NodeType.StorageType:
		auto storage = cast(ir.StorageType) type;
		extypePassStorageType(lp, current, exp, storage);
		break;
	default:
		extypeAssignDispatch(lp, current, exp, type);
		break;
	}
}

void extypePass(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Type type)
{
	ensureResolved(lp, current, type);
	if (handleStructLiteral(lp, current, exp, type)) return;
	if (handleNull(lp, current, exp, type)) return;

	extypePassHandleStorage(lp, current, exp, type);

	extypePassDispatch(lp, current, exp, type);
}

void extypeAssign(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Type type)
{
	ensureResolved(lp, current, type);
	if (handleStructLiteral(lp, current, exp, type)) return;
	if (handleNull(lp, current, exp, type)) return;

	extypeAssignHandleStorage(lp, current, exp, type);

	extypeAssignDispatch(lp, current, exp, type);
}

/**
 * Replace IdentifierExps with ExpReferences.
 */
void extypeIdentifierExp(LanguagePass lp, ir.Scope current, ref ir.Exp e, ir.IdentifierExp i)
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
		throw new CompilerError(i.location, format("unidentified identifier '%s'.", i.value));
	}

	auto _ref = new ir.ExpReference();
	_ref.idents ~= i.value;
	_ref.location = i.location;

	if (store.kind == ir.Store.Kind.Value) {
		auto var = cast(ir.Variable) store.node;
		assert(var !is null);
		_ref.decl = var;
		e = _ref;
		return;
	} else if (store.kind == ir.Store.Kind.Function) {
		if (store.functions.length != 1)
			throw CompilerPanic(i.location, "can not take function pointers from overloaded functions");

		/// @todo Figure out if this is a delegate or not.
		auto fn = cast(ir.Function) store.functions[0];
		assert(fn !is null);
		_ref.decl = fn;
		e = _ref;
		return;
	} else if (store.kind == ir.Store.Kind.Template) {
		throw new CompilerError(i.location, "template used as a value");
	} else if (store.kind == ir.Store.Kind.Type) {
		return;
	}

	throw CompilerPanic(i.location, format("unhandled identifier type '%s'.", i.value));
}

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
			auto asStorage = cast(ir.StorageType) type;
			if (asStorage !is null && canTransparentlyReferToBase(asStorage)) {
				type = asStorage.base;
			}

			if (type.nodeType != ir.NodeType.Struct && type.nodeType != ir.NodeType.Class) {
				return;
			}

			/// @todo this is probably an error.
			auto aggScope = getScopeFromType(type);
			auto store = lookupAsThisScope(lp, aggScope, postfix.location, postfix.identifier.value);
			if (store is null) {
				throw new CompilerError(postfix.location, format("aggregate has no member '%s'.", postfix.identifier.value));
			}

			if (store.kind != ir.Store.Kind.Function) {
				return;
			}

			/// @todo handle function overloading.
			assert(store.functions.length == 1);

			auto funcref = new ir.ExpReference();
			funcref.location = postfix.identifier.location;
			auto _ref = cast(ir.ExpReference) postfix.child;
			if (_ref !is null) funcref.idents = _ref.idents;
			funcref.idents ~= postfix.identifier.value;
			funcref.decl = store.functions[0];
			postfix.op = ir.Postfix.Op.CreateDelegate;
			postfix.memberFunction = funcref;
		}

		propertyToCallIfNeeded(postfix.location, lp, exp, current, postfixes);

		return;
	}

	auto type = getExpType(lp, postfix.child, current);
	auto asFunctionType = cast(ir.CallableType) type;
	if (asFunctionType is null) {
		throw new CompilerError(postfix.location, format("tried to call uncallable type."));
	}

	if (asFunctionType.isScope && postfix.child.nodeType == ir.NodeType.Postfix) {
		auto asPostfix = cast(ir.Postfix) postfix.child;
		auto parentType = getExpType(lp, asPostfix.child, current);
		if (mutableIndirection(parentType)) {
			auto asStorageType = cast(ir.StorageType) parentType;
			if (asStorageType is null || asStorageType.type != ir.StorageType.Kind.Scope) {
				throw new CompilerError(postfix.location, "cannot call scope function on non scope instance.");
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
			throw new CompilerError(postfix.location, "not enough arguments to vararg function");
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
		string emsg = format("expected %s argument%s, got %s.", asFunctionType.params.length, 
							 asFunctionType.params.length != 1 ? "s" : "", postfix.arguments.length);
		throw new CompilerError(postfix.location, emsg);
	}
	assert(asFunctionType.params.length <= postfix.arguments.length);
	foreach (i; 0 .. asFunctionType.params.length) {
		if (asFunctionType.params[i].isRef && !isLValue(postfix.arguments[i])) {
			throw new CompilerError(postfix.arguments[i].location, "expression is not an lvalue");
		}
		extypePass(lp, current, postfix.arguments[i], asFunctionType.params[i].type);
	}
}

void extypeExpReference(LanguagePass lp, ir.Scope current, ref ir.Exp e, ir.ExpReference reference)
{
	// Turn references to @property functions into calls.
	propertyToCallIfNeeded(e.location, lp, e, current, null);

	/// If we can find it locally, don't insert a this, even if it's in a this. (i.e. shadowing).
	auto sstore = lookupOnlyThisScope(lp, current, e.location, reference.idents[$-1]);
	if (sstore !is null) {
		return;
	}

	ir.Scope _;
	ir.Class _class;
	bool foundClass = current.getFirstClass(_, _class);
	if (foundClass) {
		auto asFunction = cast(ir.Function) current.node;
		if (asFunction is null) {
			return;
		}

		auto store = lookupAsThisScope(lp, _class.myScope, reference.location, reference.idents[$-1]);
		if (store is null) {
			return;
		}
		ir.Function memberFunction;
		if (store.functions.length > 0) {
			assert(store.functions.length == 1);
			memberFunction = store.functions[0];
		}

		store = lookup(lp, current, reference.location, "this");
		if (store is null || store.kind != ir.Store.Kind.Value) {
			throw CompilerPanic("function doesn't have this");
		}

		auto asVar = cast(ir.Variable)store.node;
		assert(asVar !is null);

		auto thisRef = new ir.ExpReference();
		thisRef.location = reference.location;
		thisRef.idents ~= "this";
		thisRef.decl = asVar;

		auto postfix = new ir.Postfix();
		postfix.location = reference.location;
		postfix.op = ir.Postfix.Op.Identifier;
		postfix.identifier = new ir.Identifier();
		postfix.identifier.location = reference.location;
		postfix.identifier.value = reference.idents[0];
		postfix.child = thisRef;
		if (memberFunction !is null) {
			postfix.op = ir.Postfix.Op.CreateDelegate;
			postfix.memberFunction = buildExpReference(postfix.location, memberFunction);
		}

		e = postfix;
		lp.actualize(_class);
		return;
	}

	auto varStore = lookupOnlyThisScope(lp, current, reference.location, reference.idents[$-1]);
	if (varStore !is null) {
		return;
	}

	auto thisStore = lookupOnlyThisScope(lp, current, reference.location, "this");
	if (thisStore is null) {
		return;
	}

	auto asVar = cast(ir.Variable) thisStore.node;
	assert(asVar !is null);
	auto asTR = cast(ir.TypeReference) asVar.type;
	assert(asTR !is null);

	auto aggScope = getScopeFromType(asTR.type);
	varStore = lookupOnlyThisScope(lp, aggScope, reference.location, reference.idents[0]);
	if (varStore is null) {
		return;
	}
	ir.Function memberFunction;
	if (varStore.functions.length > 0) {
		assert(varStore.functions.length == 1);
		memberFunction = varStore.functions[0];
	}

	// Okay, it looks like reference isn't pointing at a local, and it exists in a this.
	auto thisRef = new ir.ExpReference();
	thisRef.location = reference.location;
	thisRef.idents ~= "this";
	thisRef.decl = asVar;

	auto postfix = new ir.Postfix();
	postfix.location = reference.location;
	postfix.op = ir.Postfix.Op.Identifier;
	postfix.identifier = new ir.Identifier();
	postfix.identifier.location = reference.location;
	postfix.identifier.value = reference.idents[0];
	postfix.child = thisRef;
	if (memberFunction !is null) {
		postfix.op = ir.Postfix.Op.CreateDelegate;
		postfix.memberFunction = buildExpReference(postfix.location, memberFunction);
	}

	e = postfix;
	return;
}

void extypeLeaveBinOp(LanguagePass lp, ir.Scope current, ref ir.Exp e, ir.BinOp bin)
{
	if (bin.op != ir.BinOp.Type.Assign) {
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

void extypePostfixIdentifier(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Postfix postfix)
{
	if (postfix.op != ir.Postfix.Op.Identifier)
		return;

	ir.Postfix[] postfixIdents; // In reverse order.
	ir.IdentifierExp identExp; // The top of the stack.
	ir.Postfix currentP = postfix;

	while (true) {
		if (currentP.identifier is null)
			throw CompilerPanic(currentP.location, "null identifier");

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
			break;
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
			assert(var !is null);
			_ref.decl = var;
		} else if (store.kind == ir.Store.Kind.Function) {
			assert(store.functions.length == 1);
			auto fn = store.functions[0];
			_ref.decl = fn;
		} else {
			auto emsg = format("unhandled Store kind: '%s'.", to!string(store.kind));
			throw CompilerPanic(_ref.location, emsg);
		}

		// Sanity check.
		if (_ref.decl is null) {
			throw CompilerPanic(_ref.location, "empty ExpReference declaration.");
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
			throw new CompilerError(loc, format("unknown identifier '%s'.", ident));
		}

		final switch(store.kind) with (ir.Store.Kind) {
		case Scope:
		case Type:
			_scope = getScopeFromStore(store);
			if (_scope is null)
				throw CompilerPanic(loc, "missing scope");

			if (postfixIdents.length == 0)
				throw new CompilerError(loc, "expected value or function not type/scope");

			postfix = postfixIdents[0];
			postfixIdents = postfixIdents[1 .. $];
			ident = postfix.identifier.value;
			loc = postfix.identifier.location;

			store = lookupOnlyThisScope(lp, _scope, loc, ident);
			idents = [ident] ~ idents;

			break;
		case Template:
			throw new CompilerError(loc, "template used as a type or value");
		case Value:
		case Function:
			filloutReference(store);
			break;
		case Alias:
			throw CompilerPanic(loc, "alias scope");
		}

	} while(_ref is null);

	assert(_ref !is null);

	// We are retriving a Variable or Function directly.
	if (postfixIdents.length == 0) {
		exp = _ref;
		return;
	} else {
		postfix = postfixIdents[0];
		postfix.child = _ref;
	}
}

void extypePostfix(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.Postfix postfix)
{
	rewriteSuperIfNeeded(exp, postfix, current, lp);
	extypePostfixIdentifier(lp, current, exp, postfix);
}

void handleCastTo(LanguagePass lp, ir.Scope current, ir.Unary unary)
{
	if (unary.type is null || unary.value is null) {
		return;
	}

	auto to = getClass(unary.type);
	auto from = getClass(getExpType(lp, unary.value, current));

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

void extypeUnary(LanguagePass lp, ir.Scope current, ir.Unary _unary)
{
	handleCastTo(lp, current, _unary);

	// Needed because of "new Foo();" in ExpStatement.
	if (_unary.type !is null) {
		ensureResolved(lp, current, _unary.type);
	}

	if (!_unary.hasArgumentList) {
		return;
	}
	auto tr = cast(ir.TypeReference) _unary.type;
	if (tr is null) {
		return;
	}
	auto _class = cast(ir.Class) tr.type;
	if (_class is null) {
		return;
	}

	// Needed because of userConstructors.
	lp.actualize(_class);

	assert(_class.userConstructors.length == 1);
	if (_unary.argumentList.length != _class.userConstructors[0].type.params.length) {
		throw new CompilerError(_unary.location, "mismatched argument count for constructor.");
	}

	auto fn = _class.userConstructors[0];

	lp.resolve(fn);

	for (size_t i = 0; i < _unary.argumentList.length; ++i) {
		extypeAssign(lp, current, _unary.argumentList[i], fn.type.params[i].type);
	}
	return;
}

void extypeBinOp(LanguagePass lp, ir.Scope current, ir.BinOp bin, ir.PrimitiveType lprim, ir.PrimitiveType rprim)
{
	auto leftsz = size(lprim.type);
	auto rightsz = size(rprim.type);

	bool leftUnsigned = isUnsigned(lprim.type);
	bool rightUnsigned = isUnsigned(rprim.type);
	if (leftUnsigned != rightUnsigned) {
		if (leftUnsigned) {
			if (fitsInPrimitive(lprim, bin.right)) {
				bin.right = buildCastSmart(lprim, bin.right);
				rightUnsigned = true;
			}
		} else {
			if (fitsInPrimitive(rprim, bin.left)) {
				bin.left = buildCastSmart(rprim, bin.left);
				leftUnsigned = true;
			}
		}
		if (leftUnsigned != rightUnsigned) {
			throw new CompilerError(bin.location, "binary operation with both signed and unsigned operands.");
		}
	}

	auto intsz = size(ir.PrimitiveType.Kind.Int);
	int largestsz;
	ir.Type largestType;

	if (leftsz > rightsz) {
		largestsz = leftsz;
		largestType = lprim;
	} else {
		largestsz = rightsz;
		largestType = rprim;
	}

	if (bin.op != ir.BinOp.Type.Assign && intsz > largestsz) {
		largestsz = intsz;
		largestType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
	}

	if (leftsz < largestsz) {
		bin.left = buildCastSmart(largestType, bin.left);
	}

	if (rightsz < largestsz) {
		bin.right = buildCastSmart(largestType, bin.right);
	}
}

void extypeBinOp(LanguagePass lp, ir.Scope current, ir.BinOp binop)
{
	auto ltype = getExpType(lp, binop.left, current);
	auto rtype = getExpType(lp, binop.right, current);

	if (handleNull(lp, current, binop.left, rtype)) return;
	if (handleNull(lp, current, binop.right, ltype)) return;

	if (binop.op == ir.BinOp.Type.Assign) {
		if (effectivelyConst(ltype)) {
			throw new CompilerError(binop.location, "cannot assign to const type.");
		}
		extypeAssign(lp, current, binop.right, ltype);
		return;
	}

	if (binop.op == ir.BinOp.Type.AndAnd || binop.op == ir.BinOp.Type.OrOr) {
		auto boolType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		if (!typesEqual(ltype, boolType)) {
			binop.left = buildCastSmart(boolType, binop.left);
		}
		if (!typesEqual(rtype, boolType)) {
			binop.right = buildCastSmart(boolType, binop.right);
		}
		return;
	}

	if (ltype.nodeType == ir.NodeType.PrimitiveType && rtype.nodeType == ir.NodeType.PrimitiveType) {
		auto lprim = cast(ir.PrimitiveType) ltype;
		auto rprim = cast(ir.PrimitiveType) rtype;
		assert(lprim !is null && rprim !is null);
		extypeBinOp(lp, current, binop, lprim, rprim);
	}
}

void extypeTernary(LanguagePass lp, ir.Scope current, ir.Ternary ternary)
{
	auto baseType = getExpType(lp, ternary.ifTrue, current);
	extypeAssign(lp, current, ternary.ifFalse, baseType);

	auto condType = getExpType(lp, ternary.condition, current);
	if (!isBool(condType)) {
		ternary.condition = buildCastToBool(ternary.condition.location, ternary.condition);
	}
}

/// Replace TypeOf with its expression's type, if needed.
void replaceTypeOfIfNeeded(LanguagePass lp, ir.Scope current, ref ir.Type type)
{
	auto asTypeOf = cast(ir.TypeOf) type;
	if (asTypeOf is null) {
		assert(type.nodeType != ir.NodeType.TypeOf);
		return;
	}

	type = copyTypeSmart(asTypeOf.location, getExpType(lp, asTypeOf.exp, current));
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
class ExTyper : ScopeExpReplaceVisitor, Pass
{
public:
	LanguagePass lp;
	bool enterFirstVariable;

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
		this.enterFirstVariable = true;
		accept(v, this);
		this.current = null;
	}

	override void close()
	{
	}

	override Status visit(ref ir.Exp exp, ir.IdentifierExp ie)
	{
		extypeIdentifierExp(lp, current, exp, ie);
		auto eref = cast(ir.ExpReference) exp;
		assert(eref !is null);
		extypeExpReference(lp, current, exp, eref);
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		lp.actualize(s);
		super.enter(s);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		lp.actualize(c);
		super.enter(c);
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		// This has to be done this way, because the order in
		// which the calls in this and the visiting functions
		// are exectuted matters.
		if (!enterFirstVariable) {
			lp.resolve(current, v);
			return ContinueParent;
		}
		enterFirstVariable = true;

		ensureResolved(lp, current, v.type);

		NullExpReplaceVisitor.enter(v);
		replaceTypeOfIfNeeded(lp, current, v.type);

		if (v.assign !is null) {
			extypeAssign(lp, current, v.assign, v.type);
		}

		replaceStorageIfNeeded(v.type);

		return Continue;
	}

	override Status enter(ir.BinOp binop)
	{
		extypeBinOp(lp, current, binop);
		return Continue;
	}

	override Status enter(ir.ReturnStatement ret)
	{
		NullExpReplaceVisitor.enter(ret);

		auto fn = cast(ir.Function) current.node;
		if (fn is null) {
			throw CompilerPanic(ret.location, "return statement outside of function.");
		}

		if (ret.exp !is null) {
			extypeAssign(lp, current, ret.exp, fn.type.ret);
		}

		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		lp.resolve(fn);
		super.enter(fn);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.Postfix postfix)
	{
		extypePostfix(lp, current, exp, postfix);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Postfix postfix)
	{
		extypeLeavePostfix(lp, current, exp, postfix);
		return Continue;
	}

	override Status enter(ir.IfStatement ifs)
	{
		NullExpReplaceVisitor.enter(ifs);
		extypeCastToBool(lp, current, ifs.exp);
		return Continue;
	}

	override Status enter(ir.ForStatement fs)
	{
		NullExpReplaceVisitor.enter(fs);
		if (fs.test !is null) extypeCastToBool(lp, current, fs.test);
		return Continue;
	}

	override Status enter(ir.WhileStatement ws)
	{
		NullExpReplaceVisitor.enter(ws);
		extypeCastToBool(lp, current, ws.condition);
		return Continue;
	}

	override Status enter(ir.DoStatement ds)
	{
		NullExpReplaceVisitor.enter(ds);
		extypeCastToBool(lp, current, ds.condition);
		return Continue;
	}

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

	override Status enter(ir.Typeid _typeid)
	{
		ensureResolved(lp, current, _typeid.type);
		replaceTypeOfIfNeeded(lp, current, _typeid.type);
		return Continue;
	}

	override Status enter(ir.Unary _unary)
	{
		extypeUnary(lp, current, _unary);
		return Continue;
	}

	override Status enter(ir.Ternary ternary)
	{
		extypeTernary(lp, current, ternary);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.ExpReference reference)
	{
		extypeExpReference(lp, current, exp, reference);
		return Continue;
	}

	/// If this is an assignment to a @property function, turn it into a function call.
	override Status leave(ref ir.Exp e, ir.BinOp bin)
	{
		extypeLeaveBinOp(lp, current, e, bin);
		return Continue;
	}

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}
}
