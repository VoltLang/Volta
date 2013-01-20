// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// Routines to retrieve the types of expressions.
module volt.semantic.typer;

import std.conv : to;
import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.exceptions;
import volt.token.location;
import volt.semantic.classify;
import volt.semantic.lookup;

/// Look up a Variable and return its type.
ir.Type declTypeLookup(ir.Scope _scope, string name, Location location)
{
	auto store = _scope.lookup(name, location);
	if (store is null) {
		throw new CompilerError(location, format("undefined identifier '%s'.", name));
	}
	if (store.kind == ir.Store.Kind.Function) {
		/// @todo Overloading.
		assert(store.functions.length == 1);
		return store.functions[0].type;
	}

	if (store.kind == ir.Store.Kind.Scope) {
		assert(false);
		//auto asMod = cast(ir.Module) store.s.node;
		//assert(asMod !is null);
		//return asMod;
	}

	auto d = cast(ir.Variable) store.node;
	if (d is null) {
		throw new CompilerError(location, format("%s used as value.", name));
	}
	return d.type;
}

/// Given a scope, get the oldest parent -- this should be the module of that scope.
ir.Scope getTopScope(ir.Scope currentScope)
{
	ir.Scope current = currentScope;
	while (current.parent !is null) {
		current = current.parent;
	}
	return current;
}

/**
 * Get the type of a given expression.
 *
 * If the operation of the expression isn't semantically valid
 * for the given type, a CompilerError is thrown.
 */
ir.Type getExpType(ir.Exp exp, ir.Scope currentScope)
{
	auto result = getExpTypeImpl(exp, currentScope);
	while (result.nodeType == ir.NodeType.TypeReference) {
		auto asTR = cast(ir.TypeReference) result;
		assert(asTR !is null);
		result = asTR.type;
	}
	return result;
}

/**
 * Retrieve the type of the given expression.
 */
ir.Type getExpTypeImpl(ir.Exp exp, ir.Scope currentScope)
{
	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		auto asConstant = cast(ir.Constant) exp;
		assert(asConstant !is null);
		return getConstantType(asConstant);
	case IdentifierExp:
		auto asIdentifierExp = cast(ir.IdentifierExp) exp;
		assert(asIdentifierExp !is null);
		return getIdentifierExpType(asIdentifierExp, currentScope);
	case TypeReference:
		auto asTR = cast(ir.TypeReference) exp;
		assert(asTR !is null);
		return getTypeReferenceType(asTR);
	case ArrayLiteral:
		auto asLiteral = cast(ir.ArrayLiteral) exp;
		assert(asLiteral !is null);
		return getArrayLiteralType(asLiteral, currentScope);
	case Unary:
		auto asUnary = cast(ir.Unary) exp;
		assert(asUnary !is null);
		return getUnaryType(asUnary, currentScope);
	case Typeid:
		auto asTypeid = cast(ir.Typeid) exp;
		assert(asTypeid !is null);
		return getTypeidType(asTypeid, currentScope);
	case Postfix:
		auto asPostfix = cast(ir.Postfix) exp;
		assert(asPostfix !is null);
		return getPostfixType(asPostfix, currentScope);
	case BinOp:
		auto asBinOp = cast(ir.BinOp) exp;
		assert(asBinOp !is null);
		return getBinOpType(asBinOp, currentScope);
	case ExpReference:
		auto asExpRef = cast(ir.ExpReference) exp;
		assert(asExpRef !is null);
		return getExpReferenceType(asExpRef);
	default:
		throw CompilerPanic(format("unable to type expression '%s'.", to!string(exp.nodeType)));
	}
}

ir.Type getExpReferenceType(ir.ExpReference expref)
{
	if (expref.decl is null) {
		throw CompilerPanic(expref.location, "unable to type expression reference.");
	}

	auto var = cast(ir.Variable) expref.decl;
	if (var !is null) {
		return var.type;
	}

	auto fn = cast(ir.Function) expref.decl;
	if (fn !is null) {
		return fn.type;
	}

	throw CompilerPanic(expref.location, "unable to type expression reference.");
}

ir.Type getBinOpType(ir.BinOp bin, ir.Scope currentScope)
{
	ir.Type left = getExpType(bin.left, currentScope);
	ir.Type right = getExpType(bin.right, currentScope);
	
	if (isComparison(bin.op)) {
		auto boolType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		boolType.location = bin.location;
		return boolType;
	}

	if (effectivelyConst(left) && bin.op == ir.BinOp.Type.Assign) {
		throw new CompilerError(bin.location, "cannot assign to const type.");
	}
	
	if (left.nodeType == ir.NodeType.PrimitiveType &&
		right.nodeType == ir.NodeType.PrimitiveType) {
		auto lprim = cast(ir.PrimitiveType) left;
		auto rprim = cast(ir.PrimitiveType) right;
		assert(lprim !is null && rprim !is null);
		if (lprim.type.size() > rprim.type.size()) {
			return left;
		} else {
			return right;
		}
	} else if (left.nodeType == ir.NodeType.PointerType &&
			   right.nodeType == ir.NodeType.PointerType) {
		if (bin.op == ir.BinOp.Type.Assign) {
			return left;
		} else if (bin.op == ir.BinOp.Type.Is || bin.op == ir.BinOp.Type.NotIs) {
			auto boolType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
			boolType.location = bin.location;
			return boolType;
		} else {
			throw new CompilerError(bin.location, "invalid binary operation for pointer types.");
		}
	} else if (left.nodeType == ir.NodeType.ArrayType ||
			   right.nodeType == ir.NodeType.ArrayType) {
		if (!(bin.op == ir.BinOp.Type.Cat || bin.op == ir.BinOp.Type.Assign)) {
			throw new CompilerError(bin.location, "can only concatenate arrays.");
		}
		if (left.nodeType == ir.NodeType.ArrayType) {
			auto array = cast(ir.ArrayType) left;
			assert(array !is null);
			return array;
		} else if (right.nodeType == ir.NodeType.ArrayType) {
			auto array = cast(ir.ArrayType) right;
			assert(array !is null);
			return array;
		}
	} else if ((left.nodeType == ir.NodeType.PointerType && right.nodeType != ir.NodeType.PointerType) ||
               (left.nodeType != ir.NodeType.PointerType && right.nodeType == ir.NodeType.PointerType)) {
		if (!isValidPointerArithmeticOperation(bin.op)) {
			throw new CompilerError(bin.location, "invalid operation for pointer arithmetic.");
		}
		ir.PrimitiveType prim;
		ir.PointerType pointer;
		if (left.nodeType == ir.NodeType.PrimitiveType) {
			prim = cast(ir.PrimitiveType) left;
			pointer = cast(ir.PointerType) right;
		} else {
			prim = cast(ir.PrimitiveType) right;
			pointer = cast(ir.PointerType) left;
		}
		assert(pointer !is null);
		return pointer;
	} else {
		auto lt = cast(ir.Type) left;
		auto rt = cast(ir.Type) right;
		if (lt !is null && rt !is null && typesEqual(lt, rt)) {
			return lt;
		} else {
			throw new CompilerError(bin.location, "cannot implicitly reconcile binary expression types.");
		}
	}

	assert(false);
}

ir.Type getTypeidType(ir.Typeid _typeid, ir.Scope currentScope)
{
	return retrieveTypeInfoClass(_typeid.location, currentScope);
}

ir.Type getConstantType(ir.Constant constant)
{
	return constant.type;
}

ir.Type getIdentifierExpType(ir.IdentifierExp identifierExp, ir.Scope currentScope)
{
	if (identifierExp.type is null) {
		if (identifierExp.globalLookup) {
			identifierExp.type = declTypeLookup(getTopScope(currentScope), identifierExp.value, identifierExp.location);
		} else {
			identifierExp.type = declTypeLookup(currentScope, identifierExp.value, identifierExp.location);
		}
	}
	assert(identifierExp.type !is null);
	auto asType = cast(ir.Type) identifierExp.type;
	assert(asType !is null);
	return asType;
}

ir.Type getTypeReferenceType(ir.TypeReference typeReference)
{
	return typeReference.type;
}

ir.Type getArrayLiteralType(ir.ArrayLiteral arrayLiteral, ir.Scope currentScope)
{
	if (arrayLiteral.type !is null) {
		return arrayLiteral.type;
	}
	ir.Type base;
	if (arrayLiteral.values.length > 0) {
		/// @todo figure out common subtype stuff. For now, D1 stylin'.
		base = copyTypeSmart(arrayLiteral.location,
			getExpType(arrayLiteral.values[0], currentScope));
	} else {
		base = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
		base.location = arrayLiteral.location;
	}
	assert(base !is null);
	arrayLiteral.type = new ir.ArrayType(base);
	arrayLiteral.type.location = arrayLiteral.location;
	return arrayLiteral.type;
}

ir.Type getPostfixType(ir.Postfix postfix, ir.Scope currentScope)
{
	switch (postfix.op) with (ir.Postfix.Op) {
	case Index:
		return getPostfixIndexType(postfix, currentScope);
	case Slice:
		return getPostfixSliceType(postfix, currentScope);
	case Call:
		return getPostfixCallType(postfix, currentScope);
	case Increment, Decrement:
		return getPostfixIncDecType(postfix, currentScope);
	case Identifier:
		return getPostfixIdentifierType(postfix, currentScope);
	case CreateDelegate:
		return getPostfixCreateDelegateType(postfix, currentScope);
	default:
		auto emsg = format("unhandled postfix op type '%s'", to!string(postfix.op));
		throw CompilerPanic(postfix.location, emsg);
	}
}

ir.Type getPostfixSliceType(ir.Postfix postfix, ir.Scope currentScope)
{
	ir.ArrayType array;
	ir.PointerType pointer;

	auto type = getExpType(postfix.child, currentScope);
	if (type.nodeType == ir.NodeType.PointerType) {
		pointer = cast(ir.PointerType) type;
		assert(pointer !is null);
	} else if (type.nodeType == ir.NodeType.ArrayType) {
		array = cast(ir.ArrayType) type;
		assert(array !is null);
	} else {
		throw new CompilerError(postfix.location, "tried to index non array or pointer.");
	}

	if (array is null) {
		assert(pointer !is null);
		array = new ir.ArrayType(pointer.base);
		array.location = postfix.location;
	}

	return array;
}

ir.Type getPostfixCreateDelegateType(ir.Postfix postfix, ir.Scope currentScope)
{
	auto err = CompilerPanic(postfix.location, "couldn't retrieve type from CreateDelegate postfix.");

	auto eref = cast(ir.ExpReference) postfix.memberFunction;
	if (eref is null) {
		throw err;
	}

	auto fn = cast(ir.Function) eref.decl;
	if (fn is null) {
		throw err;
	}

	auto dg = new ir.DelegateType(fn.type);
	dg.location = postfix.location;
	return dg;
}

ir.Type getSizeT(Location location, ir.Scope currentScope)
{
	auto store = currentScope.lookup("size_t", location);
	if (store is null) {
		throw CompilerPanic(location, "couldn't retrieve size_t.");
	}
	auto type = cast(ir.PrimitiveType) store.node;
	assert(type !is null);
	return type;
}

void retrieveScope(ir.Node tt, ir.Postfix postfix, ref ir.Scope _scope, ref ir.Class _class, ref string emsg)
{
	if (tt.nodeType == ir.NodeType.Module) {
		auto asModule = cast(ir.Module) tt;
		assert(asModule !is null);
		_scope = asModule.myScope;
		emsg = format("module '%s' has no member '%s'.", asModule.name, postfix.identifier.value);
	} else if (tt.nodeType == ir.NodeType.Class || tt.nodeType == ir.NodeType.Struct) {
		if (tt.nodeType == ir.NodeType.Struct) {
			auto asStruct = cast(ir.Struct) tt;
			_scope = asStruct.myScope;
			emsg = format("type '%s' has no member '%s'.", asStruct.name, postfix.identifier.value);
		} else if (tt.nodeType == ir.NodeType.Class) {
			_class = cast(ir.Class) tt;
			_scope = _class.myScope;
			emsg = format("type '%s' has no member '%s'.", _class.name, postfix.identifier.value);
		} else {
			throw CompilerPanic("couldn't retrieve scope from type.");
		}
	} else if (tt.nodeType == ir.NodeType.PointerType) {
		auto asPointer = cast(ir.PointerType) tt;
		assert(asPointer !is null);
		retrieveScope(asPointer.base, postfix, _scope, _class, emsg);
	} else if (tt.nodeType == ir.NodeType.TypeReference) {
		auto asTR = cast(ir.TypeReference) tt;
		assert(asTR !is null);
		retrieveScope(asTR.type, postfix, _scope, _class, emsg);
	} else if (tt.nodeType == ir.NodeType.StorageType) {
		auto asStorage = cast(ir.StorageType) tt;
		assert(asStorage !is null);
		retrieveScope(asStorage.base, postfix, _scope, _class, emsg);
	} else {
		assert(false, to!string(tt.nodeType));
	}
}

ir.Type getPostfixIdentifierType(ir.Postfix postfix, ir.Scope currentScope)
{
	ir.Scope _scope;
	ir.Class _class;
	string emsg;

	/* If postfix.child is an identifier expression, we check to see if it
	 * refers to a module. If it is, we fill in _scope and emsg and jump
	 * to the lookup. 
	 *
	 * This is unpleasant, sure, but it allows the get*Type functions to return
	 * a Type rather than a Node (as a module is not a Type) that we would have
	 * to if we had to retrieve modules through the mechanism we get the other
	 * scopes.
	 */
	auto asIdentifierExp = cast(ir.IdentifierExp) postfix.child;
	if (asIdentifierExp !is null) {
		auto store = currentScope.lookup(asIdentifierExp.value, asIdentifierExp.location);
		if (store !is null && store.s !is null) {
			_scope = store.s;
			emsg = format("module '%s' did not have member '%s'.", asIdentifierExp.value, postfix.identifier.value);
			goto _lookup;
		}
	}

	auto type = getExpType(postfix.child, currentScope);

	if (type.nodeType == ir.NodeType.ArrayType) {
		auto asArray = cast(ir.ArrayType) type;
		assert(asArray !is null);
		return getPostfixIdentifierArrayType(postfix, asArray, currentScope);
	}


	retrieveScope(type, postfix, _scope, _class, emsg);

	_lookup:
	auto store = _scope.lookupOnlyThisScope(postfix.identifier.value, postfix.location);
	// If this scope came from a class and it has a parent, check the parent as well.
	if (store is null && _class !is null && _class.parentClass !is null) {
		_class = _class.parentClass;
		_scope = _class.myScope;
		goto _lookup;
	}
  
	if (store is null) {
		throw new CompilerError(postfix.identifier.location, emsg);
	}

	if (store.kind == ir.Store.Kind.Value) {
		auto asDecl = cast(ir.Variable) store.node;
		assert(asDecl !is null);
		return asDecl.type;
	} else if (store.kind == ir.Store.Kind.Function) {
		assert(store.functions.length == 1);
		return store.functions[$-1].type;
	} else {
		throw CompilerPanic(postfix.location, "unhandled postfix type retrieval.");
	}
}

ir.Type getPostfixIdentifierArrayType(ir.Postfix postfix, ir.ArrayType arrayType, ir.Scope currentScope)
{
	switch (postfix.identifier.value) {
	case "length":
		return getSizeT(postfix.location, currentScope);
	case "ptr":
		auto pointer = new ir.PointerType(arrayType.base);
		pointer.location = postfix.location;
		return pointer;
	default:
		throw new CompilerError(postfix.location, "arrays only have length and ptr members.");
	}
}

ir.Type getPostfixIncDecType(ir.Postfix postfix, ir.Scope currentScope)
{
	auto type = getExpType(postfix.child, currentScope);
	/// @todo check if value is LValue.

	if (type.nodeType == ir.NodeType.PointerType) {
		return type;
	} else if (type.nodeType == ir.NodeType.PrimitiveType &&
			   isOkayForPointerArithmetic((cast(ir.PrimitiveType)type).type)) {
		return type;
	} else if (effectivelyConst(type)) {
		throw new CompilerError(postfix.location, "cannot modify const type.");
	}

	throw new CompilerError(postfix.location, "value not suited for increment/decrement");
}

ir.Type getPostfixIndexType(ir.Postfix postfix, ir.Scope currentScope)
{
	ir.ArrayType array;
	ir.PointerType pointer;

	auto type = getExpType(postfix.child, currentScope);
	if (type.nodeType == ir.NodeType.PointerType) {
		pointer = cast(ir.PointerType) type;
		assert(pointer !is null);
	} else if (type.nodeType == ir.NodeType.ArrayType) {
		array = cast(ir.ArrayType) type;
		assert(array !is null);
	} else {
		throw new CompilerError(postfix.location, "tried to index non array or pointer.");
	}
	assert((pointer !is null && array is null) || (array !is null && pointer is null));

	return pointer is null ? array.base : pointer.base;
}

ir.Type getPostfixCallType(ir.Postfix postfix, ir.Scope currentScope)
{
	auto type = getExpType(postfix.child, currentScope);

	auto callable = cast(ir.CallableType) type;
	if (callable is null) {
		throw new CompilerError(postfix.location, "can only call functions and delegates.");
	}

	return callable.ret;
}

ir.Type getUnaryType(ir.Unary unary, ir.Scope currentScope)
{
	switch (unary.op) with (ir.Unary.Op) {
	case None:
		return getUnaryNoneType(unary, currentScope);
	case Cast:
		return getUnaryCastType(unary);
	case Dereference:
		return getUnaryDerefType(unary, currentScope);
	case AddrOf:
		return getUnaryAddrOfType(unary, currentScope);
	case New:
		return getUnaryNewType(unary);
	case Minus, Plus:
		return getUnarySubAddType(unary, currentScope);
	default:
		assert(false);
	}
}

ir.Type getUnaryNoneType(ir.Unary unary, ir.Scope currentScope)
{
	return getExpType(unary.value, currentScope);
}

ir.Type getUnaryCastType(ir.Unary unary)
{
	return unary.type;
}

ir.Type getUnaryDerefType(ir.Unary unary, ir.Scope currentScope)
{
	auto type = getExpType(unary.value, currentScope);
	// If this is a storageType(T*) make the result storageType(T).
	if (type.nodeType == ir.NodeType.StorageType) {
		ir.Type base = type;
		ir.StorageType.Kind[] kinds;
		Location[] locations;
		while (base.nodeType == ir.NodeType.StorageType) {
			auto asStorage = cast(ir.StorageType) type;
			kinds ~= asStorage.type;
			locations ~= asStorage.location;
			assert(asStorage !is null);
			base = asStorage.base;
		}
		if (base.nodeType != ir.NodeType.PointerType) {
			throw new CompilerError(unary.location, "can only dereference pointers.");
		}
		assert(kinds.length == locations.length);
		ir.StorageType outStorage = new ir.StorageType();
		for (int i = 0; i < kinds.length; ++i) {
			auto kind = kinds[i];
			auto location = locations[i];
			outStorage.type = kind;
			outStorage.location = location;
			if (i < kinds.length - 1) {
				outStorage.base = new ir.StorageType();
				outStorage = cast(ir.StorageType) outStorage.base;
			}
		}
		auto asPointer = cast(ir.PointerType) base;
		assert(asPointer !is null);
		outStorage.base = asPointer.base;
		return outStorage;
	}

	if (type.nodeType != ir.NodeType.PointerType) {
		throw new CompilerError(unary.location, "can only dereference pointers.");
	}
	auto asPointer = cast(ir.PointerType) type;
	assert(asPointer !is null);
	return asPointer.base;
}

ir.Type getUnaryAddrOfType(ir.Unary unary, ir.Scope currentScope)
{
	auto type = getExpType(unary.value, currentScope);
	auto pointer = new ir.PointerType(type);
	pointer.location = unary.location;
	return pointer;
}

ir.Type getUnaryNewType(ir.Unary unary)
{
	if (!unary.isArray && !unary.hasArgumentList) {
		auto pointer = new ir.PointerType(unary.type);
		pointer.location = unary.location;
		return pointer;
	} else if (unary.isArray) {
		auto array = new ir.ArrayType(unary.type);
		array.location = unary.location;
		return array;
	} else {
		assert(unary.hasArgumentList);
		return unary.type;
	}
}

ir.Type getUnarySubAddType(ir.Unary unary, ir.Scope currentScope)
{
	auto type = getExpType(unary.value, currentScope);
	return type;
}
