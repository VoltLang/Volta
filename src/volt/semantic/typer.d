// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// Routines to retrieve the types of expressions.
module volt.semantic.typer;

import watt.conv : toString;
import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.exceptions;
import volt.errors;
import volt.interfaces;
import volt.token.location;

import volt.semantic.util;
import volt.semantic.lookup;
import volt.semantic.classify;
import volt.semantic.overload;


/**
 * Get the type of a given expression.
 *
 * If the operation of the expression isn't semantically valid
 * for the given type, a CompilerError is thrown.
 */
ir.Type getExpType(LanguagePass lp, ir.Exp exp, ir.Scope currentScope)
{
	auto result = getExpTypeImpl(lp, exp, currentScope);
	if (result is null) {
		return null;
	}

	// Validate the returned types.
	debug {
		if  (result.nodeType == ir.NodeType.TypeReference) {
			auto asTR = cast(ir.TypeReference) result;
			panicAssert(exp, asTR !is null);
			panicAssert(asTR, asTR.type !is null);
			auto named = cast(ir.Named) asTR.type;
			panicAssert(asTR, named !is null);
		}
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
	case AccessExp:
		auto ae = cast(ir.AccessExp) exp;
		assert(ae !is null);
		return ae.field.type;
	case Constant:
		auto asConstant = cast(ir.Constant) exp;
		assert(asConstant !is null);
		return getConstantType(asConstant);
	case ArrayLiteral:
		auto asLiteral = cast(ir.ArrayLiteral) exp;
		assert(asLiteral !is null);
		return getArrayLiteralType(asLiteral);
	case AssocArray:
		auto asAssoc = cast(ir.AssocArray) exp;
		assert(asAssoc !is null);
		return getAssocArrayType(asAssoc);
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
		return getTypeidType(asTypeid);
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
		return getExpReferenceType(asExpRef);
	case TraitsExp:
		auto asTraits = cast(ir.TraitsExp) exp;
		assert(asTraits !is null);
		return getTraitsExpType(asTraits);
	case StructLiteral:
		auto asStructLiteral = cast(ir.StructLiteral) exp;
		assert(asStructLiteral !is null);
		return getStructLiteralType(asStructLiteral);
	case ClassLiteral:
		auto asClassLiteral = cast(ir.ClassLiteral) exp;
		assert(asClassLiteral !is null);
		return getClassLiteralType(asClassLiteral);
	case TypeExp:
		auto asTypeExp = cast(ir.TypeExp) exp;
		assert(asTypeExp !is null);
		return getTypeExpType(asTypeExp);
	case StoreExp:
		auto asStoreExp = cast(ir.StoreExp) exp;
		assert(asStoreExp !is null);
		return getStoreExpType(asStoreExp);
	case StatementExp:
		auto asStatementExp = cast(ir.StatementExp) exp;
		assert(asStatementExp !is null);
		return getStatementExpType(lp, asStatementExp, currentScope);
	case TokenExp:
		auto asTokenExp = cast(ir.TokenExp) exp;
		assert(asTokenExp !is null);
		return getTokenExpType(asTokenExp);
	case VaArgExp:
		auto asVaArgExp = cast(ir.VaArgExp) exp;
		assert(asVaArgExp !is null);
		return getVaArgType(asVaArgExp);
	case IsExp:
		return buildBool(exp.location);
	case PropertyExp:
		auto prop = cast(ir.PropertyExp) exp;
		return getPropertyExpType(prop);
	case BuiltinExp:
		auto inbuilt = cast(ir.BuiltinExp) exp;
		return inbuilt.type;
	case StringImport:
		return buildString(exp.location);
	default:
		throw panicUnhandled(exp, ir.nodeToString(exp));
	}
}

ir.Type getVaArgType(ir.VaArgExp vaexp)
{
	return vaexp.type;
}

ir.Type getTokenExpType(ir.TokenExp texp)
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

ir.Type getTypeExpType(ir.TypeExp te)
{
	return te.type;
}

ir.Type getStoreExpType(ir.StoreExp se)
{
	assert(se.store !is null);
	auto t = cast(ir.Type) se.store.node;
	if (t !is null) {
		return t;
	}

	return buildNoType(se.location);
}

ir.Type getStructLiteralType(ir.StructLiteral slit)
{
	if (slit.type is null) {
		throw panic(slit.location, "null struct literal");
	}
	return slit.type;
}

ir.Type getClassLiteralType(ir.ClassLiteral clit)
{
	return clit.type;
}

ir.Type getTraitsExpType(ir.TraitsExp te)
{
	panicAssert(te, te.type !is null);
	return te.type;
}

ir.Type getExpReferenceType(ir.ExpReference expref)
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

	auto func = cast(ir.Function) expref.decl;
	if (func !is null) {
		if (func.nestedHiddenParameter !is null) {
			auto t = new ir.DelegateType(func.type);
			t.isScope = true;
			return t;
		}
		if (func.type is null) {
			throw panic(func.location, format("function '%s' has null type", func.name));
		}
		return func.type;
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

	auto funcset = cast(ir.FunctionSet) expref.decl;
	panicAssert(funcset, funcset.functions.length > 0);
	if (funcset !is null) {
		auto ftype = funcset.type;
		assert(ftype.set.functions.length > 0);
		panicAssert(funcset, ftype !is null);
		return ftype;
	}

	throw panic(expref.location, "unable to type expression reference.");
}

ir.Type getBinOpType(LanguagePass lp, ir.BinOp bin, ir.Scope currentScope)
{
	ir.Type left = getExpType(lp, bin.left, currentScope);
	ir.Type right = getExpType(lp, bin.right, currentScope);
	bool assign = bin.op.isAssign();

	if (isComparison(bin.op)) {
		auto boolType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		boolType.location = bin.location;
		return boolType;
	}

	if (effectivelyConst(left) && assign) {
		throw panic(bin.location, "modifying const type expression passed to typer.");
	}

	if ((left.isConst | left.isImmutable | left.isScope) && !assign) {
		left = copyTypeSmart(bin.location, left);
		left.isConst = false;
		left.isImmutable = false;
		left.isScope = false;
	}

	if (left.nodeType == ir.NodeType.PrimitiveType &&
		right.nodeType == ir.NodeType.PrimitiveType) {
		auto lprim = cast(ir.PrimitiveType) left;
		auto rprim = cast(ir.PrimitiveType) right;
		assert(lprim !is null && rprim !is null);
		// Keep the left completely intact if assign.
		// For other ops, remove the charness of a type.
		if (assign) {
			return lprim;
		} else if (lprim.type.size() >= rprim.type.size()) {
			return charToInteger(lprim);
		} else {
			return charToInteger(rprim);
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
			throw panic(bin.location, "bad bin op.");
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
			throw panic(bin.location, "bad bin op.");
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
		auto lt = cast(ir.Type) realType(left);
		auto rt = cast(ir.Type) realType(right);
		if (lt !is null && rt !is null && typesEqual(lt, rt)) {
			return lt;
		} else {
			throw panic(bin.location, "bad bin op.");
		}
	}

	assert(false);
}

ir.Type getTypeidType(ir.Typeid _typeid)
{
	panicAssert(_typeid, _typeid.tinfoType !is null);
	return _typeid.tinfoType;
}

ir.Type getConstantType(ir.Constant constant)
{
	return constant.type;
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

ir.Type getArrayLiteralType(ir.ArrayLiteral al)
{
	if (al.type is null) {
		throw panic(al.location, "uninitialised array literal passed to typer.");
	}
	return al.type;
}

ir.Type getAssocArrayType(ir.AssocArray aa)
{
	panicAssert(aa, aa.type !is null);
	return aa.type;
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
		panicAssert(postfix, false);
		assert(false);
	case CreateDelegate:
		return getPostfixCreateDelegateType(postfix);
	default:
		throw panicUnhandled(postfix, toString(postfix.op));
	}
}

ir.Type getPostfixSliceType(LanguagePass lp, ir.Postfix postfix, ir.Scope currentScope)
{
	ir.Type base;
	ir.ArrayType array;

	auto type = realType(getExpType(lp, postfix.child, currentScope));
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
		throw panic(postfix.location, "unsliceable type sliced");
	}

	if (array is null) {
		assert(base !is null);
		array = new ir.ArrayType(base);
		array.location = postfix.location;
	}

	return array;
}

ir.Type getPropertyExpType(ir.PropertyExp prop)
{
	if (prop.getFn is null) {
		return buildNoType(prop.location);
	} else {
		return prop.getFn.type.ret;
	}
}

ir.Type getPostfixCreateDelegateType(ir.Postfix postfix)
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

	auto func = cast(ir.Function) eref.decl;
	if (func is null) {
		throw err;
	}
	if (func.kind != ir.Function.Kind.Nested && !isFunctionMemberOrConstructor(func)) {
		throw panic(postfix.location, "static function called through instance");
	}

	auto dg = new ir.DelegateType(func.type);
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
	           tt.nodeType == ir.NodeType.Class || tt.nodeType == ir.NodeType.UserAttribute || tt.nodeType == ir.NodeType.Interface) {
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
		} else if (tt.nodeType == ir.NodeType.Interface) {
			auto asIface = cast(ir._Interface) tt;
			_scope = asIface.myScope;
			emsg = format("type '%s' has no member '%s'.", asIface.name, postfix.identifier.value);
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
	} else if (tt.nodeType == ir.NodeType.Enum) {
		auto asEnum = cast(ir.Enum) tt;
		assert(asEnum !is null);
		_scope = asEnum.myScope;
		emsg = format("enum '%s' has no member '%s'.", asEnum.name, postfix.identifier.value);
	} else if (tt.nodeType == ir.NodeType.FunctionSetType) {
		auto fset = cast(ir.FunctionSetType) tt;
		ir.Function[] properties;
		foreach (func; fset.set.functions) {
			if (func.type.isProperty && func.params.length == 0) {
				properties ~= func;
			}
		}
		if (properties.length == 1) {
			return retrieveScope(lp, properties[0].type.ret, postfix, _scope, _class, emsg);
		} else {
			throw panic(postfix.location, "bad scope lookup");
		}
	} else {
		throw panic(postfix.location, "bad scope lookup");
	}
}

ir.Type getPostfixIncDecType(LanguagePass lp, ir.Postfix postfix, ir.Scope currentScope)
{
	if (!isLValue(postfix.child)) {
		throw panic(postfix.location, "expected lvalue.");
	}
	auto otype = getExpType(lp, postfix.child, currentScope);
	auto type = realType(otype);

	if (type.nodeType == ir.NodeType.PointerType) {
		return type;
	} else if (type.nodeType == ir.NodeType.PrimitiveType &&
			   isOkayForPointerArithmetic((cast(ir.PrimitiveType)type).type)) {
		return type;
	} else if (effectivelyConst(otype)) {
		throw panic(postfix.location, "modify const in typer.");
	}

	throw panic(postfix.location, "bad postfix operation in typer.");
}

ir.Type getPostfixIndexType(LanguagePass lp, ir.Postfix postfix, ir.Scope currentScope)
{
	ir.Type base;

	auto type = realType(getExpType(lp, postfix.child, currentScope));

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
		auto named = cast(ir.Named) type;
		if (named is null) {
			throw panic(postfix.location, "bad postfix operation in typer.");
		}
		auto store = named.myScope.getStore(overloadIndexName());
		if (store is null || store.functions.length != 1) {
			throw panic(postfix.location, "bad postfix operation in typer.");
		}
		base = store.functions[0].type.ret;
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
		auto func = selectFunction(lp, currentScope, set.set, postfix.arguments, postfix.location);
		if (set.isFromCreateDelegate) {
			if (!isFunctionMemberOrConstructor(func)) {
				throw panic(postfix.location, "calling static through instance in typer.");
			}
			ftype = new ir.DelegateType(func.type);
		} else {
			ftype = func.type;
		}
	} else {
		ftype = cast(ir.CallableType) type;
	}

	if (ftype is null) {
		throw panic(postfix.location, "bad call in typer.");
	}

	return ftype.ret;
}

ir.Type getTernaryType(LanguagePass lp, ir.Ternary ternary, ir.Scope currentScope)
{
	auto itype = getExpType(lp, ternary.ifTrue, currentScope);
	return removeStorageFields(itype);
}

ir.Type getUnaryType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	final switch (unary.op) with (ir.Unary.Op) {
	case Cast:
		return getUnaryCastType(unary);
	case Dereference:
		return getUnaryDerefType(lp, unary, currentScope);
	case AddrOf:
		return getUnaryAddrOfType(lp, unary, currentScope);
	case New:
		return getUnaryNewType(lp, unary, currentScope);
	case Dup:
		throw panic(unary.location, "tried to type dup exp.");
	case Minus, Plus:
		return getUnarySubAddType(lp, unary, currentScope);
	case Not:
		return getUnaryNotType(unary);
	case Complement:
		return getUnaryComplementType(lp, unary, currentScope);
	case Increment, Decrement:
		return getUnaryIncDecType(lp, unary, currentScope);
	case TypeIdent:
		throw panicUnhandled(unary, "unary TypeIdent");
	case None:
		throw panicUnhandled(unary, "unary None");
	}
}

ir.Type getUnaryIncDecType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	if (!isLValue(unary.value)) {
		throw panic(unary.location, "not lvalue for unary inc/dec in typer.");
	}
	auto type = getExpType(lp, unary.value, currentScope);

	if (type.nodeType == ir.NodeType.PointerType) {
		return type;
	} else if (type.nodeType == ir.NodeType.PrimitiveType &&
			   isOkayForPointerArithmetic((cast(ir.PrimitiveType)type).type)) {
		return type;
	} else if (effectivelyConst(type)) {
		throw panic(unary.location, "modifying const type in typer.");
	}

	throw panic(unary.location, "bad unary operation in typer.");
}

ir.Type getUnaryComplementType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	return getExpType(lp, unary.value, currentScope);
}

ir.Type getUnaryNotType(ir.Unary unary)
{
	return buildBool(unary.location);
}

ir.Type getUnaryCastType(ir.Unary unary)
{
	panicAssert(unary, unary.type !is null);
	return unary.type;
}

ir.Type getUnaryDerefType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	auto type = getExpType(lp, unary.value, currentScope);
	if (type.nodeType != ir.NodeType.PointerType) {
		throw panic(unary.location, "bad unary operation in typer.");
	}
	auto asPointer = cast(ir.PointerType) type;
	assert(asPointer !is null);
	auto t = copyTypeSmart(asPointer.base.location, asPointer.base);
	addStorage(t, asPointer);
	return t;
}

ir.Type getUnaryAddrOfType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
	if (!isLValue(unary.value)) {
		throw panic(unary.location, "non lvalue addrof in typer.");
	}
	auto type = getExpType(lp, unary.value, currentScope);
	auto pointer = new ir.PointerType(type);
	pointer.location = unary.location;
	return pointer;
}

ir.Type getUnaryNewType(LanguagePass lp, ir.Unary unary, ir.Scope currentScope)
{
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
