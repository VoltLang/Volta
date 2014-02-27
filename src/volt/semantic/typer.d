// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// Routines to retrieve the types of expressions.
module volt.semantic.typer;

import std.conv : to;
import std.string : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.semantic.classify;
import volt.semantic.lookup;
import volt.semantic.util;
import volt.semantic.overload;

/// Look up a Variable and return its type.
ir.Type declTypeLookup(Location loc, LanguagePass lp, ir.Scope _scope, string name)
{
	auto store = lookup(lp, _scope, loc, name);
	if (store is null) {
		throw makeFailedLookup(loc, name);
	}
	if (store.kind == ir.Store.Kind.Function) {
		return buildSetType(loc, store.functions);
	}

	if (store.kind == ir.Store.Kind.Scope) {
		assert(false);
	}

	auto d = cast(ir.Variable) store.node;
	if (d !is null) {
		return d.type;
	}
	auto ed = cast(ir.EnumDeclaration) store.node;
	if (ed !is null) {
		return ed.type;
	}
	auto fp = cast(ir.FunctionParam) store.node;
	if (fp !is null) {
		return fp.type;
	}
	auto e = cast(ir.Enum) store.node;
	if (e !is null) {
		return e;
	}
	auto t = cast(ir.Type) store.node;
	if (t !is null) {
		return t;
	}
	throw makeExpected(loc, "type");
}

/**
 * Remove types masking a type (e.g. enum).
 */
ir.Type realType(ir.Type t, bool stripEnum = true, bool stripStorage = false)
{
	auto tr = cast(ir.TypeReference) t;
	if (tr !is null) {
		return realType(tr.type, stripEnum, stripStorage);
	}
	if (stripEnum) {
		auto e = cast(ir.Enum) t;
		if (e !is null) {
			return realType(e.base, stripEnum, stripStorage);
		}
	}
	if (stripStorage) {
		auto st = cast(ir.StorageType) t;
		if (st !is null) {
			return realType(st.base, stripEnum, stripStorage);
		}
	}
	return t;
}

/**
 * Get the type of a given expression.
 *
 * If the operation of the expression isn't semantically valid
 * for the given type, a CompilerError is thrown.
 */
ir.Type getExpType(LanguagePass lp, ir.Exp exp, ir.Scope currentScope)
{
	auto result = getExpTypeImpl(lp, exp, currentScope);
	while (result.nodeType == ir.NodeType.TypeReference) {
		auto asTR = cast(ir.TypeReference) result;
		assert(asTR !is null);
		ensureResolved(lp, currentScope, asTR);
		result = asTR.type;
	}
	auto storage = cast(ir.StorageType) result;
	if (storage !is null && canTransparentlyReferToBase(storage)) {
		result = storage.base;
	}
	if (result is null) {
		throw panic(exp.location, "null getExpType result.");
	}
	return result;
}

/**
 * Retrieve the type of the given expression.
 */
ir.Type getExpTypeImpl(LanguagePass lp, ir.Exp exp, ir.Scope currentScope)
{
	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		auto asConstant = cast(ir.Constant) exp;
		assert(asConstant !is null);
		return getConstantType(lp, asConstant);
	case IdentifierExp:
		auto asIdentifierExp = cast(ir.IdentifierExp) exp;
		assert(asIdentifierExp !is null);
		return getIdentifierExpType(lp, asIdentifierExp, currentScope);
	case ArrayLiteral:
		auto asLiteral = cast(ir.ArrayLiteral) exp;
		assert(asLiteral !is null);
		return getArrayLiteralType(lp, asLiteral, currentScope);
	case AssocArray:
		auto asAssoc = cast(ir.AssocArray) exp;
		assert(asAssoc !is null);
		return getAssocArrayType(lp, asAssoc, currentScope);
	case Ternary:
		auto asTernary = cast(ir.Ternary) exp;
		assert(asTernary !is null);
		return getTernaryType(lp, asTernary, currentScope);
	case Unary:
		auto asUnary = cast(ir.Unary) exp;
		assert(asUnary !is null);
		return getUnaryType(lp, asUnary, currentScope);
	case Typeid:
		auto asTypeid = cast(ir.Typeid) exp;
		assert(asTypeid !is null);
		return getTypeidType(lp, asTypeid, currentScope);
	case Postfix:
		auto asPostfix = cast(ir.Postfix) exp;
		assert(asPostfix !is null);
		return getPostfixType(lp, asPostfix, currentScope);
	case BinOp:
		auto asBinOp = cast(ir.BinOp) exp;
		assert(asBinOp !is null);
		return getBinOpType(lp, asBinOp, currentScope);
	case ExpReference:
		auto asExpRef = cast(ir.ExpReference) exp;
		assert(asExpRef !is null);
		return getExpReferenceType(lp, asExpRef, currentScope);
	case TraitsExp:
		auto asTraits = cast(ir.TraitsExp) exp;
		assert(asTraits !is null);
		return getTraitsExpType(lp, asTraits, currentScope);
	case StructLiteral:
		auto asStructLiteral = cast(ir.StructLiteral) exp;
		assert(asStructLiteral !is null);
		return getStructLiteralType(lp, asStructLiteral);
	case ClassLiteral:
		auto asClassLiteral = cast(ir.ClassLiteral) exp;
		assert(asClassLiteral !is null);
		return getClassLiteralType(lp, asClassLiteral);
	case TypeExp:
		auto asTypeExp = cast(ir.TypeExp) exp;
		assert(asTypeExp !is null);
		return getTypeExpType(lp, asTypeExp);
	case StatementExp:
		auto asStatementExp = cast(ir.StatementExp) exp;
		assert(asStatementExp !is null);
		return getStatementExpType(lp, asStatementExp, currentScope);
	case TokenExp:
		auto asTokenExp = cast(ir.TokenExp) exp;
		assert(asTokenExp !is null);
		return getTokenExpType(lp, asTokenExp, currentScope);
	case VaArgExp:
		auto asVaArgExp = cast(ir.VaArgExp) exp;
		assert(asVaArgExp !is null);
		return getVaArgType(lp, asVaArgExp, currentScope);
	default:
		throw panicUnhandled(exp, to!string(exp.nodeType));
	}
}

ir.Type getVaArgType(LanguagePass lp, ir.VaArgExp vaexp, ir.Scope currentScope)
{
	return vaexp.type;
}

ir.Type getTokenExpType(LanguagePass lp, ir.TokenExp texp, ir.Scope currentScope)
{
	if (texp.type == ir.TokenExp.Type.Line) {
		return buildInt(texp.location);
	} else {
		return buildString(texp.location);
	}
}

ir.Type getStatementExpType(LanguagePass lp, ir.StatementExp se, ir.Scope currentScope)
{
	assert(se.exp !is null);
	return getExpType(lp, se.exp, currentScope);
}

ir.Type getTypeExpType(LanguagePass lp, ir.TypeExp te)
{
	return te.type;
}

ir.Type getStructLiteralType(LanguagePass lp, ir.StructLiteral slit)
{
	return slit.type;
}

ir.Type getClassLiteralType(LanguagePass lp, ir.ClassLiteral clit)
{
	return clit.type;
}

ir.Type getTraitsExpType(LanguagePass lp, ir.TraitsExp traits, ir.Scope _scope)
{
	assert(traits.op == ir.TraitsExp.Op.GetAttribute);
	auto store = lookup(lp, _scope, traits.qname);
	auto attr = cast(ir.UserAttribute) store.node;
	if (attr is null) {
		throw makeExpected(traits, "@inteface");
	}
	lp.actualize(attr);
	return attr.layoutClass;
}

ir.Type getExpReferenceType(LanguagePass lp, ir.ExpReference expref, ir.Scope currentScope)
{
	if (expref.decl is null) {
		throw panic(expref.location, "unable to type expression reference.");
	}

	auto var = cast(ir.Variable) expref.decl;
	if (var !is null) {
		if (var.type is null) {
			throw panic(var.location, format("variable '%s' has null type", var.name));
		}
		return var.type;
	}

	auto fn = cast(ir.Function) expref.decl;
	if (fn !is null) {
		if (fn.nestedHiddenParameter !is null) {
			return buildStorageType(fn.location, ir.StorageType.Kind.Scope, new ir.DelegateType(fn.type));
		}
		if (fn.type is null) {
			throw panic(fn.location, format("function '%s' has null type", fn.name));
		}
		return fn.type;
	}

	auto ed = cast(ir.EnumDeclaration) expref.decl;
	if (ed !is null) {
		if (ed.type is null) {
			throw panic(ed.location, "enum declaration has null type");
		}
		return ed.type;
	}

	auto fp = cast(ir.FunctionParam) expref.decl;
	if (fp !is null) {
		if (fp.type is null) {
			throw panic(fp.location, format("function parameter '%s' has null type", fp.name));
		}
		return fp.type;
	}

	auto fnset = cast(ir.FunctionSet) expref.decl;
	assert(fnset.functions.length > 0);
	if (fnset !is null) {
		auto ftype = fnset.type;
		assert(ftype.set.functions.length > 0);
		panicAssert(fnset, ftype !is null);
		return ftype;
	}

	throw panic(expref.location, "unable to type expression reference.");
}

ir.Type getBinOpType(LanguagePass lp, ir.BinOp bin, ir.Scope currentScope)
{
	ir.Type left = getExpType(lp, bin.left, currentScope);
	ir.Type right = getExpType(lp, bin.right, currentScope);

	if (isComparison(bin.op)) {
		auto boolType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		boolType.location = bin.location;
		return boolType;
	}

	if (effectivelyConst(left) && bin.op == ir.BinOp.Op.Assign) {
		throw makeCannotModify(bin, left);
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
		if (bin.op == ir.BinOp.Op.Assign) {
			return left;
		} else if (bin.op == ir.BinOp.Op.Is || bin.op == ir.BinOp.Op.NotIs) {
			auto boolType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
			boolType.location = bin.location;
			return boolType;
		} else {
			throw makeBadImplicitCast(bin, right, left);
		}
	} else if (left.nodeType == ir.NodeType.ArrayType ||
			   right.nodeType == ir.NodeType.ArrayType) {
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
			throw makeBadImplicitCast(bin, right, left);
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
	} else if ((left.nodeType == ir.NodeType.StorageType && right.nodeType != ir.NodeType.StorageType) ||
			   (left.nodeType != ir.NodeType.StorageType && right.nodeType == ir.NodeType.StorageType)) {
		ir.StorageType storage = cast(ir.StorageType) left;
		ir.Type other = right;
		if (storage is null) {
			storage = cast(ir.StorageType) right;
			other = left;
		}
		assert(storage !is null);
		while (storage.base.nodeType == ir.NodeType.StorageType) {
			storage = cast(ir.StorageType) storage.base;
		}
		assert(storage !is null);
		if (!mutableIndirection(storage.base) && isImplicitlyConvertable(storage.base, other)) {
			return other;
		}
		throw makeBadImplicitCast(bin, right, left);
	} else {
		auto lt = cast(ir.Type) realType(left);
		auto rt = cast(ir.Type) realType(right);
		if (lt !is null && rt !is null && typesEqual(lt, rt)) {
			return lt;
		} else {
			throw makeBadImplicitCast(bin, right, left);
		}
	}

	assert(false);
}

ir.Type getTypeidType(LanguagePass lp, ir.Typeid _typeid, ir.Scope currentScope)
{
	return lp.typeInfoClass;
}

ir.Type getConstantType(LanguagePass lp, ir.Constant constant)
{
	return constant.type;
}

ir.Type getIdentifierExpType(LanguagePass lp, ir.IdentifierExp identifierExp, ir.Scope currentScope)
{
	if (identifierExp.type is null) {
		if (identifierExp.globalLookup) {
			identifierExp.type = declTypeLookup(identifierExp.location, lp, getTopScope(currentScope), identifierExp.value);
		} else {
			identifierExp.type = declTypeLookup(identifierExp.location, lp, currentScope, identifierExp.value);
		}
	}
	assert(identifierExp.type !is null);
	auto asType = cast(ir.Type) identifierExp.type;
	assert(asType !is null);
	return asType;
}

ir.Type getCommonSubtype(Location l, ir.Type[] types)
{
	bool arrayElementSubtype(ir.Type element, ir.Type proposed)
	{
		if (typesEqual(element, proposed)) {
			return true;
		}
		auto aclass = cast(ir.Class) element;
		auto bclass = cast(ir.Class) proposed;
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

ir.Type getArrayLiteralType(LanguagePass lp, ir.ArrayLiteral arrayLiteral, ir.Scope currentScope)
{
	if (arrayLiteral.type !is null) {
		return arrayLiteral.type;
	}
	ir.Type base;
	if (arrayLiteral.values.length > 0) {
		/// @todo figure out common subtype stuff. For now, D1 stylin'.
		base = getCommonSubtype(arrayLiteral.location, expsToTypes(lp, arrayLiteral.values, currentScope));
		base = copyTypeSmart(arrayLiteral.location, base);
	} else {
		base = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
		base.location = arrayLiteral.location;
	}
	assert(base !is null);
	arrayLiteral.type = new ir.ArrayType(base);
	arrayLiteral.type.location = arrayLiteral.location;
	return arrayLiteral.type;
}

ir.Type getAssocArrayType(LanguagePass lp, ir.AssocArray assocArray, ir.Scope currentScope)
{
	ir.Type base;
	if (assocArray.pairs.length > 0) {
		auto pair = assocArray.pairs[0];
		base = buildAATypeSmart(assocArray.location,
			getExpType(lp, pair.key, currentScope),
			getExpType(lp, pair.value, currentScope)
		);
	} else {
		base = assocArray.type;
	}

	assert(base !is null);
	auto aaType = new ir.AAType();
	aaType.key = (cast(ir.AAType)base).key;
	aaType.value = (cast(ir.AAType)base).value;
	assocArray.type = aaType;
	assocArray.type.location = assocArray.location;
	return base;
}

ir.Type getPostfixType(LanguagePass lp, ir.Postfix postfix, ir.Scope currentScope)
{
	switch (postfix.op) with (ir.Postfix.Op) {
	case Index:
		return getPostfixIndexType(lp, postfix, currentScope);
	case Slice:
		return getPostfixSliceType(lp, postfix, currentScope);
	case Call:
		return getPostfixCallType(lp, postfix, currentScope);
	case Increment, Decrement:
		return getPostfixIncDecType(lp, postfix, currentScope);
	case Identifier:
		return getPostfixIdentifierType(lp, postfix, currentScope);
	case CreateDelegate:
		return getPostfixCreateDelegateType(lp, postfix, currentScope);
	default:
		throw panicUnhandled(postfix, to!string(postfix.op));
	}
}

ir.Type getPostfixSliceType(LanguagePass lp, ir.Postfix postfix, ir.Scope currentScope)
{
	ir.Type base;
	ir.ArrayType array;

	auto type = getExpType(lp, postfix.child, currentScope);
	if (type.nodeType == ir.NodeType.PointerType) {
		auto pointer = cast(ir.PointerType) type;
		assert(pointer !is null);
		base = pointer.base;
	} else if (type.nodeType == ir.NodeType.StaticArrayType) {
		auto staticArray = cast(ir.StaticArrayType) type;
		assert(staticArray !is null);
		base = staticArray.base;
	} else if (type.nodeType == ir.NodeType.ArrayType) {
		array = cast(ir.ArrayType) type;
		assert(array !is null);
	} else {
		throw makeBadOperation(postfix);
	}

	if (array is null) {
		assert(base !is null);
		array = new ir.ArrayType(base);
		array.location = postfix.location;
	}

	return array;
}

ir.Type getPostfixCreateDelegateType(LanguagePass lp, ir.Postfix postfix, ir.Scope currentScope)
{
	auto err = panic(postfix.location, "couldn't retrieve type from CreateDelegate postfix.");

	auto eref = cast(ir.ExpReference) postfix.memberFunction;
	if (eref is null) {
		throw err;
	}

	auto fset = cast(ir.FunctionSet) eref.decl;
	if (fset !is null) {
		auto ftype = fset.type;
		assert(ftype.set.functions.length > 0);
		ftype.isFromCreateDelegate = true;
		return ftype;
	}

	auto fn = cast(ir.Function) eref.decl;
	if (fn is null) {
		throw err;
	}
	if (!isFunctionMemberOrConstructor(fn)) {
		throw makeCallingStaticThroughInstance(postfix, fn);
	}

	auto dg = new ir.DelegateType(fn.type);
	dg.location = postfix.location;
	return dg;
}

void retrieveScope(LanguagePass lp, ir.Node tt, ir.Postfix postfix, ref ir.Scope _scope, ref ir.Class _class, ref string emsg)
{
	if (tt.nodeType == ir.NodeType.Module) {
		auto asModule = cast(ir.Module) tt;
		assert(asModule !is null);
		_scope = asModule.myScope;
		emsg = format("module '%s' has no member '%s'.", asModule.name, postfix.identifier.value);
	} else if (tt.nodeType == ir.NodeType.Struct || tt.nodeType == ir.NodeType.Union ||
	           tt.nodeType == ir.NodeType.Class || tt.nodeType == ir.NodeType.UserAttribute) {
		if (tt.nodeType == ir.NodeType.Struct) {
			auto asStruct = cast(ir.Struct) tt;
			_scope = asStruct.myScope;
			emsg = format("type '%s' has no member '%s'.", asStruct.name, postfix.identifier.value);
		} else if (tt.nodeType == ir.NodeType.Union) {
			auto asUnion = cast(ir.Union) tt;
			_scope = asUnion.myScope;
			emsg = format("type '%s' has no member '%s'.", asUnion.name, postfix.identifier.value);
		} else if (tt.nodeType == ir.NodeType.Class) {
			_class = cast(ir.Class) tt;
			_scope = _class.myScope;
			emsg = format("type '%s' has no member '%s'.", _class.name, postfix.identifier.value);
		} else if (tt.nodeType == ir.NodeType.UserAttribute) {
			auto asAttr = cast(ir.UserAttribute) tt;
			_scope = asAttr.myScope;
			emsg = format("type '%s' has no member '%s'.", asAttr.name, postfix.identifier.value);
		} else {
			throw panic("couldn't retrieve scope from type.");
		}
	} else if (tt.nodeType == ir.NodeType.PointerType) {
		auto asPointer = cast(ir.PointerType) tt;
		assert(asPointer !is null);
		retrieveScope(lp, asPointer.base, postfix, _scope, _class, emsg);
	} else if (tt.nodeType == ir.NodeType.TypeReference) {
		auto asTR = cast(ir.TypeReference) tt;
		assert(asTR !is null);
		retrieveScope(lp, asTR.type, postfix, _scope, _class, emsg);
	} else if (tt.nodeType == ir.NodeType.StorageType) {
		auto asStorage = cast(ir.StorageType) tt;
		assert(asStorage !is null);
		retrieveScope(lp, asStorage.base, postfix, _scope, _class, emsg);
	} else if (tt.nodeType == ir.NodeType.Enum) {
		auto asEnum = cast(ir.Enum) tt;
		assert(asEnum !is null);
		_scope = asEnum.myScope;
		emsg = format("enum '%s' has no member '%s'.", asEnum.name, postfix.identifier.value);
	} else {
		auto type = cast(ir.Type) tt;
		assert(type !is null);
		throw makeNotMember(postfix, type, postfix.identifier.value);
	}
}

ir.Type getPostfixIdentifierType(LanguagePass lp, ir.Postfix postfix, ir.Scope currentScope)
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
	ir.Type type;
	ir.Aggregate agg;
	ir.PointerType asPointer;
	if (asIdentifierExp !is null) {
		auto store = lookup(lp, currentScope, asIdentifierExp.location, asIdentifierExp.value);
		if (store !is null && store.s !is null) {
			_scope = store.s;
			emsg = format("module '%s' did not have member '%s'.", asIdentifierExp.value, postfix.identifier.value);
			goto _lookup;
		}
	}

	type = realType(getExpType(lp, postfix.child, currentScope), false, true);
	asPointer = cast(ir.PointerType) type;
	if (asPointer !is null && (asPointer.base.nodeType == ir.NodeType.ArrayType 
		|| asPointer.base.nodeType == ir.NodeType.StaticArrayType)) {
		type = asPointer.base;
	}

	if (type.nodeType == ir.NodeType.ArrayType) {
		auto asArray = cast(ir.ArrayType) type;
		assert(asArray !is null);
		return getPostfixIdentifierArrayType(lp, postfix, asArray, currentScope);
	} else if (type.nodeType == ir.NodeType.StaticArrayType) {
		auto asStaticArray = cast(ir.StaticArrayType) type;
		assert(asStaticArray !is null);
		return getPostfixIdentifierStaticArrayType(lp, postfix, asStaticArray, currentScope);
	} else if (type.nodeType == ir.NodeType.AAType) {
		auto asAssocArray = cast(ir.AAType) type;
		assert(asAssocArray !is null);
		return getPostfixIdentifierAssocArrayType(lp, postfix, asAssocArray, currentScope);
	}

	retrieveScope(lp, type, postfix, _scope, _class, emsg);
	agg = cast(ir.Aggregate) realType(type);

	_lookup:
	auto store = lookupAsThisScope(lp, _scope, postfix.location, postfix.identifier.value);

	if (store is null) {
		if (agg !is null) foreach (aa; agg.anonymousAggregates) {
			assert(postfix.identifier !is null);
			auto tmpStore = lookupAsThisScope(lp, aa.myScope, postfix.location, postfix.identifier.value);
			if (tmpStore is null) {
				continue;
			}
			if (store !is null) {
				throw makeAnonymousAggregateRedefines(aa, postfix.identifier.value);
			}
			store = tmpStore;
		}
		if (store is null) {
			throw makeError(postfix.identifier.location, emsg);
		}
	}

	if (store.kind == ir.Store.Kind.Value) {
		auto asDecl = cast(ir.Variable) store.node;
		assert(asDecl !is null);
		return asDecl.type;
	} else if (store.kind == ir.Store.Kind.Function) {
		if (store.functions[0].type.isProperty) {
			if (store.functions.length > 1) {
				throw makeExpected(postfix.location, "arguments for overloaded function set");
			}
			return store.functions[0].type.ret;
		}
		return buildSetType(postfix.location, store.functions);
	} else if (store.kind == ir.Store.Kind.EnumDeclaration) {
		auto asEnumDecl = cast(ir.EnumDeclaration) store.node;
		return asEnumDecl.type;
	} else {
		auto t = cast(ir.Type) store.node;
		if (t is null) {
			throw panic(postfix.location, "unhandled postfix type retrieval.");
		}
		return t;
	}
}

ir.Type getPostfixIdentifierArrayType(LanguagePass lp, ir.Postfix postfix, ir.ArrayType arrayType, ir.Scope currentScope)
{
	switch (postfix.identifier.value) {
	case "length":
		return lp.settings.getSizeT(postfix.location);
	case "ptr":
		auto pointer = new ir.PointerType(arrayType.base);
		pointer.location = postfix.location;
		return pointer;
	default:
		throw makeFailedLookup(postfix, postfix.identifier.value);
	}
}

ir.Type getPostfixIdentifierStaticArrayType(LanguagePass lp, ir.Postfix postfix, ir.StaticArrayType arrayType, ir.Scope currentScope)
{
	switch (postfix.identifier.value) {
	case "length":
		return lp.settings.getSizeT(postfix.location);
	case "ptr":
		auto pointer = new ir.PointerType(arrayType.base);
		pointer.location = postfix.location;
		return pointer;
	default:
		throw makeFailedLookup(postfix, postfix.identifier.value);
	}
}

ir.Type getPostfixIdentifierAssocArrayType(LanguagePass lp, ir.Postfix postfix, ir.AAType arrayType, ir.Scope currentScope)
{
	switch (postfix.identifier.value) {
	case "keys":
		return buildArrayTypeSmart(postfix.location, arrayType.key);
	case "values":
		return buildArrayTypeSmart(postfix.location, arrayType.value);
	case "get":
		return buildFunctionTypeSmart(postfix.location, arrayType.key, arrayType.value);
	default:
		throw makeFailedLookup(postfix, postfix.identifier.value);
	}
}

ir.Type getPostfixIncDecType(LanguagePass lp, ir.Postfix postfix, ir.Scope currentScope)
{
	if (!isLValue(postfix.child)) {
		throw makeNotLValue(postfix);
	}
	auto type = getExpType(lp, postfix.child, currentScope);

	if (type.nodeType == ir.NodeType.PointerType) {
		return type;
	} else if (type.nodeType == ir.NodeType.PrimitiveType &&
			   isOkayForPointerArithmetic((cast(ir.PrimitiveType)type).type)) {
		return type;
	} else if (effectivelyConst(type)) {
		throw makeCannotModify(postfix, type);
	}

	throw makeBadOperation(postfix);
}

ir.Type getPostfixIndexType(LanguagePass lp, ir.Postfix postfix, ir.Scope currentScope)
{
	ir.Type base;

	auto type = realType(getExpType(lp, postfix.child, currentScope), true, true);

	if (type.nodeType == ir.NodeType.PointerType) {
		auto pointer = cast(ir.PointerType) type;
		assert(pointer !is null);
		base = pointer.base;
	} else if (type.nodeType == ir.NodeType.ArrayType) {
		auto array = cast(ir.ArrayType) type;
		assert(array !is null);
		base = array.base;
	} else if (type.nodeType == ir.NodeType.StaticArrayType) {
		auto staticArray = cast(ir.StaticArrayType) type;
		assert(staticArray !is null);
		base = staticArray.base;
	} else if (type.nodeType == ir.NodeType.AAType) {
		auto aa = cast(ir.AAType)type;
		assert(aa !is null);
		base = aa.value;
	} else {
		throw makeBadOperation(postfix);
	}

	assert(base !is null);
	return base;
}

ir.Type getPostfixCallType(LanguagePass lp, ir.Postfix postfix, ir.Scope currentScope)
{
	auto type = getExpType(lp, postfix.child, currentScope);

	ir.CallableType ftype;
	auto set = cast(ir.FunctionSetType) type;
	if (set !is null) {
		assert(set.set.functions.length > 0);
		auto fn = selectFunction(lp, currentScope, set.set, postfix.arguments, postfix.location);
		if (set.isFromCreateDelegate) {
			if (!isFunctionMemberOrConstructor(fn)) {
				throw makeCallingStaticThroughInstance(postfix, fn);
			}
			ftype = new ir.DelegateType(fn.type);
		} else {
			ftype = fn.type;
		}
	} else {
		ftype = cast(ir.CallableType) type;
		if (ftype is null) {
			auto _storage = cast(ir.StorageType) type;
			if (_storage !is null) {
				ftype = cast(ir.CallableType) _storage.base;
			}
		}
	}

	if (ftype is null) {
		throw makeBadCall(postfix, type);
	}

	return ftype.ret;
}

ir.Type getTernaryType(LanguagePass lp, ir.Ternary ternary, ir.Scope currentScope)
{
	return getExpType(lp, ternary.ifTrue, currentScope);
}

ir.Type getUnaryType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	final switch (unary.op) with (ir.Unary.Op) {
	case None:
		return getUnaryNoneType(lp, unary, currentScope);
	case Cast:
		return getUnaryCastType(lp, unary, currentScope);
	case Dereference:
		return getUnaryDerefType(lp, unary, currentScope);
	case AddrOf:
		return getUnaryAddrOfType(lp, unary, currentScope);
	case New:
		return getUnaryNewType(lp, unary, currentScope);
	case Minus, Plus:
		return getUnarySubAddType(lp, unary, currentScope);
	case Not:
		return getUnaryNotType(lp, unary);
	case Complement:
		return getUnaryComplementType(lp, unary, currentScope);
	case Increment, Decrement:
		return getUnaryIncDecType(lp, unary, currentScope);
	case TypeIdent:
		throw panicUnhandled(unary, "unary TypeIdent");
	}
}

ir.Type getUnaryIncDecType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	if (!isLValue(unary.value)) {
		throw makeNotLValue(unary);
	}
	auto type = getExpType(lp, unary.value, currentScope);

	if (type.nodeType == ir.NodeType.PointerType) {
		return type;
	} else if (type.nodeType == ir.NodeType.PrimitiveType &&
			   isOkayForPointerArithmetic((cast(ir.PrimitiveType)type).type)) {
		return type;
	} else if (effectivelyConst(type)) {
		throw makeCannotModify(unary, type);
	}

	throw makeBadOperation(unary);
}

ir.Type getUnaryComplementType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	return getExpType(lp, unary.value, currentScope);
}

ir.Type getUnaryNotType(LanguagePass lp, ir.Unary unary)
{
	return buildBool(unary.location);
}

ir.Type getUnaryNoneType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	return getExpType(lp, unary.value, currentScope);
}

ir.Type getUnaryCastType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	ensureResolved(lp, currentScope, unary.type);
	return unary.type;
}

ir.Type getUnaryDerefType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	auto type = getExpType(lp, unary.value, currentScope);
	// If this is a storageType(T*) make the result storageType(T).
	if (type.nodeType == ir.NodeType.StorageType) {
		ir.Type base = type;
		ir.StorageType.Kind[] kinds;
		Location[] locations;
		while (base.nodeType == ir.NodeType.StorageType) {
			auto asStorage = cast(ir.StorageType) base;
			kinds ~= asStorage.type;
			locations ~= asStorage.location;
			assert(asStorage !is null);
			base = asStorage.base;
		}
		if (base.nodeType != ir.NodeType.PointerType) {
			throw makeBadOperation(unary);
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
		throw makeBadOperation(unary);
	}
	auto asPointer = cast(ir.PointerType) type;
	assert(asPointer !is null);
	return asPointer.base;
}

ir.Type getUnaryAddrOfType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	if (!isLValue(unary.value)) {
		throw makeNotLValue(unary);
	}
	auto type = getExpType(lp, unary.value, currentScope);
	auto pointer = new ir.PointerType(type);
	pointer.location = unary.location;
	return pointer;
}

ir.Type getUnaryNewType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	ensureResolved(lp, currentScope, unary.type);

	if (!unary.hasArgumentList) {
		auto pointer = new ir.PointerType(unary.type);
		pointer.location = unary.location;
		return pointer;
	} else {
		assert(unary.hasArgumentList);
		return unary.type;
	}
}

ir.Type getUnarySubAddType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	auto type = getExpType(lp, unary.value, currentScope);
	return type;
}
