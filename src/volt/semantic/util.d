// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.util;

import std.algorithm : sort;
import std.array : array;
import std.string : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;
import volt.ir.copy;

import volt.exceptions;
import volt.interfaces;
import volt.token.location;
import volt.semantic.classify;
import volt.semantic.lookup;
import volt.semantic.typer : getExpType;
import volt.semantic.ctfe;
import volt.semantic.classify;


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

	if (postfixStack.length > 0 && postfixStack[0].isImplicitPropertyCall) {
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
		case FunctionType:
			auto t = copyTypeSmart(right.location, left);
			constant.type = t;
			return t;
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

void replaceVarArgsIfNeeded(LanguagePass lp, ir.Function fn)
{
	if (fn.type.hasVarArgs &&
	    !fn.type.varArgsProcessed &&
	    fn.type.linkage == ir.Linkage.Volt) {
		auto current = fn.myScope.parent;
		auto tinfoClass = retrieveTypeInfo(lp, current, fn.location);
		auto tr = buildTypeReference(fn.location, tinfoClass, tinfoClass.name);
		auto array = buildArrayType(fn.location, tr);
		addParam(fn.location, fn, array, "_typeids");
		fn.type.varArgsProcessed = true;
	}
}

void ensureResolved(LanguagePass lp, ir.Scope current, ir.EnumDeclaration ed)
{
	ir.EnumDeclaration[] edStack;
	ir.Exp prevExp;

	edStack ~= ed;
	while (edStack[$-1].prevEnum !is null) {
		edStack ~= edStack[$-1].prevEnum;
	}

	while (edStack.length > 0) {
		edStack[$-1].type = copyTypeSmart(edStack[$-1].location, edStack[$-1].type);
		if (edStack[$-1].assign is null && prevExp is null) {
			edStack[$-1].assign = prevExp = buildConstantInt(edStack[$-1].location, 0);
		}

		if (edStack[$-1].assign !is null) {
			edStack[$-1].assign = prevExp = evaluate(lp, current, edStack[$-1].assign);
		} else {
			auto loc = edStack[$-1].location;
			auto prevType = getExpType(lp, prevExp, current);
			if (!isIntegral(prevType)) {
				throw new CompilerError(loc, "only integral types can be auto incremented.");
			}

			edStack[$-1].assign = prevExp = evaluate(lp, current, buildAdd(loc, copyExp(prevExp), buildConstantInt(loc, 1)));
		}
		assert(prevExp !is null);
		edStack = edStack[0 .. $-1];
	}
}

/**
 * Ensures that a Store is a resolved alias.
 */
ir.Store ensureResolved(LanguagePass lp, ir.Store s)
{
	final switch (s.kind) with (ir.Store.Kind) {
	case Alias:
		lp.resolve(s);
		while (s.myAlias !is null) {
			s = s.myAlias;
		}
		return s;
	case Value:
		auto var = cast(ir.Variable)s.node;
		lp.resolve(s.parent, var);
		return s;
	case Function:
		foreach (fn; s.functions) {
			lp.resolve(fn);
		}
		return s;
	case EnumDeclaration:
		auto ed = cast(ir.EnumDeclaration)s.node;
		assert(ed !is null);
		lp.resolve(s.parent, ed);
		return s;
	case Type:
		if (s.node.nodeType == ir.NodeType.Class) {
			auto c = cast(ir.Class)s.node;
			lp.resolve(c);
		} else if (s.node.nodeType == ir.NodeType.Struct) {
			auto st = cast(ir.Struct)s.node;
			lp.resolve(st);
		} else if (s.node.nodeType == ir.NodeType.Enum) {
			auto st = cast(ir.Enum)s.node;
			lp.resolve(st);
		}
		return s;
	case Scope:
	case Template:
		return s;
	}
}

/**
 * Ensure that there are no unresolved TypeRefences in the given
 * type. Stops when encountering the first resolved TypeReference.
 */
void ensureResolved(LanguagePass lp, ir.Scope current, ir.Type type)
{
	switch (type.nodeType) with (ir.NodeType) {
	case PrimitiveType:
	case NullType:
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
		return lp.resolve(current, tr);
	case Enum:
		auto e = cast(ir.Enum)type;
		if (e.base !is null) {
			ensureResolved(lp, current, e.base);
		}
		foreach (d; e.members) {
			ensureResolved(lp, current, d);
		}
		return;
	case Class:
	case Struct:
	case TypeOf:
		return;
	default:
		string e = format("unhandled type: '%s'", to!string(type.nodeType));
		throw new CompilerError(type.location, e);
	}
}

/// Get a UserAttribute struct literal from a user Attribute.
ir.ClassLiteral getAttributeLiteral(ir.UserAttribute ua, ir.Attribute attr)
{
	auto cliteral = new ir.ClassLiteral();
	cliteral.location = attr.location;
	cliteral.type = copyTypeSmart(ua.layoutClass.location, ua.layoutClass);
	cliteral.exps = attr.arguments.dup;

	if (attr.arguments.length > ua.fields.length) {
		throw new CompilerError(attr.location, "too many expressions for @interface.");
	} else {
		cliteral.exps = attr.arguments.dup;
		foreach (field; ua.fields[attr.arguments.length .. $]) {
			if (field.assign is null) {
				throw new CompilerError(field.location, "expected field to have default initialiser.");
			}
			cliteral.exps ~= copyExp(field.assign);
		}
	}
	if (cliteral.exps.length != ua.fields.length) {
		throw new CompilerError(attr.location, "not every @interface field filled.");
	}
	return cliteral;
}

void replaceTraits(ref ir.Exp exp, ir.TraitsExp traits, LanguagePass lp, ir.Module thisModule, ir.Scope _scope)
{
	assert(traits.type == ir.TraitsExp.Type.GetAttribute);
	auto store = lookup(lp, _scope, traits.qname);
	auto uattr = cast(ir.UserAttribute) store.node;
	if (uattr is null) {
		throw new CompilerError(traits.qname.location, format("cannot find UserAttribute '%s'.", traits.qname));
	}

	ir.Attribute[] userAttrs;
	string name;

	store = lookup(lp, _scope, traits.target);

	switch (store.node.nodeType) with (ir.NodeType) {
	case Variable:
		auto var = cast(ir.Variable) store.node;
		userAttrs = var.userAttrs;
		name = var.name;
		break;
	case Function:
		auto fn = cast(ir.Function) store.node;
		userAttrs = fn.userAttrs;
		name = fn.name;
		break;
	case Class:
		auto _class = cast(ir.Class) store.node;
		userAttrs = _class.userAttrs;
		name = _class.name;
		break;
	case Struct:
		auto _struct = cast(ir.Struct) store.node;
		userAttrs = _struct.userAttrs;
		name = _struct.name;
		break;
	default:
		assert(false, to!string(store.node.nodeType));
	}

	ir.Attribute userAttribute;
	for (int i = cast(int)userAttrs.length - 1; i >= 0; i--) {
		if (uattr is userAttrs[i].userAttribute) {
			userAttribute = userAttrs[i];
		}
	}
	if (userAttribute is null) {
		auto str = format("'%s' has no '%s' user attribute.", traits.target, traits.qname);
		throw new CompilerError(exp.location, str);
	}

	exp = getAttributeLiteral(userAttribute.userAttribute, userAttribute);
}
