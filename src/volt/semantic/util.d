// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.util;

import std.array : array;
import std.string : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;
import volt.ir.copy;

import volt.errors;
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
			auto oldPostfix = cast(ir.Postfix) e;
			auto postfix = buildCall(loc, e, null);
			postfix.isImplicitPropertyCall = true;
			e = postfix;
			if (oldPostfix !is null) {
				oldPostfix.isImplicitPropertyCall = true;
			}
			if (asRef !is null) {
				asRef.rawReference = true;
			}
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
			throw panic(right.location, "non constant null");
		}

		while (true) switch (left.nodeType) with (ir.NodeType) {
		case PointerType:
			constant.type = buildVoidPtr(right.location);
			right = buildCastSmart(right.location, left, right);
			return copyTypeSmart(right.location, left);
		case ArrayType:
			right = buildArrayLiteralSmart(right.location, left);
			return copyTypeSmart(right.location, left);
		case FunctionType, DelegateType:
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
		case Interface:
			auto _interface = cast(ir._Interface) left;
			if (_interface !is null) {
				auto t = copyTypeSmart(right.location, _interface);
				constant.type = t;
				return t;
			}
			goto default;
		case StorageType:
			auto storage = cast(ir.StorageType) left;
			return handleNull(storage.base, right, rightType);
		default:
			throw makeBadImplicitCast(right, rightType, left);
		}
	}
	return null;
}

ir.Variable getThisVar(Location location, LanguagePass lp, ir.Scope _scope)
{
	auto fn = getParentFunction(_scope);
	if (fn is null) {
		throw panic(location, "getThisVar called for scope outside of function.");
	}
	auto thisStore = lookupOnlyThisScope(lp, fn.myScope, location, "this");
	if (thisStore is null) {
		if (fn.nestStruct !is null) {
			thisStore = lookupOnlyThisScope(lp, fn.nestStruct.myScope, location, "this");
		}
		if (thisStore is null) {
			throw makeCallingWithoutInstance(location);
		}
	}
	auto thisVar = cast(ir.Variable) thisStore.node;
	if (thisVar is null) {
		throw panic(location, "this is not variable.");
	}
	return thisVar;
}

void replaceVarArgsIfNeeded(LanguagePass lp, ir.Function fn)
{
	if (fn.type.hasVarArgs &&
	    !fn.type.varArgsProcessed &&
	    fn.type.linkage == ir.Linkage.Volt) {
		auto current = fn.myScope.parent;
		auto tinfoClass = lp.typeInfoClass;
		auto tr = buildTypeReference(fn.location, tinfoClass, tinfoClass.name);
		auto array = buildArrayType(fn.location, tr);
		auto argArray = buildArrayType(fn.location, buildVoid(fn.location));
		addParam(fn.location, fn, array, "_typeids");
		addParam(fn.location, fn, argArray, "_args");
		fn.type.varArgsProcessed = true;
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
	case FunctionParam:
		auto fp = cast(ir.FunctionParam)s.node;
		ensureResolved(lp, s.parent, fp.type);
		return s;
	case Function:
		foreach (fn; s.functions) {
			lp.resolve(s.parent, fn);
		}
		return s;
	case EnumDeclaration:
		auto ed = cast(ir.EnumDeclaration)s.node;
		assert(ed !is null);
		lp.resolve(s.parent, ed);
		return s;
	case Type:
		if (s.node.nodeType == ir.NodeType.Enum) {
			auto e = cast(ir.Enum)s.node;
			lp.resolveNamed(e);
		} else if (s.node.nodeType == ir.NodeType.Class) {
			auto c = cast(ir.Class)s.node;
			lp.resolveNamed(c);
		} else if (s.node.nodeType == ir.NodeType.Struct) {
			auto st = cast(ir.Struct)s.node;
			lp.resolveNamed(st);
		} else if (s.node.nodeType == ir.NodeType.Enum) {
			auto st = cast(ir.Enum)s.node;
			lp.resolveNamed(st);
		} else if (s.node.nodeType == ir.NodeType.Interface) {
			auto i = cast(ir._Interface)s.node;
			lp.resolveNamed(i);
		}
		return s;
	case Scope:
	case Template:
	case Expression:
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
			ensureResolved(lp, current, p);
		}
		return;
	case DelegateType:
		auto dt = cast(ir.DelegateType)type;
		ensureResolved(lp, current, dt.ret);
		foreach (p; dt.params) {
			ensureResolved(lp, current, p);
		}
		return;
	case TypeReference:
		auto tr = cast(ir.TypeReference)type;
		return lp.resolve(current, tr);
	case Enum:
		auto e = cast(ir.Enum)type;
		return lp.resolveNamed(e);
	case AAType:
		auto at = cast(ir.AAType)type;
		lp.resolve(current, at);
		return;
	case Class:
	case Struct:
	case Union:
	case TypeOf:
	case Interface:
		return;
	default:
		throw panicUnhandled(type, to!string(type.nodeType));
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
		throw makeWrongNumberOfArguments(attr, attr.arguments.length, ua.fields.length);
	} else {
		cliteral.exps = attr.arguments.dup;
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
	auto uattr = cast(ir.UserAttribute) store.node;
	if (uattr is null) {
		throw makeFailedLookup(traits, traits.qname.toString());
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
		throw makeNotMember(exp.location, traits.target.toString(), traits.qname.toString());
	}

	exp = getAttributeLiteral(userAttribute.userAttribute, userAttribute);
}

ir.Type[] expsToTypes(LanguagePass lp, ir.Exp[] exps, ir.Scope currentScope)
{
	auto types = new ir.Type[](exps.length);
	for (size_t i = 0; i < exps.length; i++) {
		types[i] = getExpType(lp, exps[i], currentScope);
	}
	return types;
}

/**
 * Gets a default value (The .init -- 0, or null, usually) for a given type.
 */
ir.Exp getDefaultInit(Location l, LanguagePass lp, ir.Scope current, ir.Type t)
{
	if (t is null) {
		throw panic(l, "null type");
	}
	switch (t.nodeType) {
	case ir.NodeType.TypeReference:
		auto tr = cast(ir.TypeReference) t;
		return getDefaultInit(l, lp, current, tr.type);
	case ir.NodeType.Enum:
		auto e = cast(ir.Enum) t;
		return getDefaultInit(l, lp, current, e.base);
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
	case ir.NodeType.StaticArrayType:
		return buildArrayLiteralSmart(l, t, []);
	case ir.NodeType.PointerType:
	case ir.NodeType.Class:
	case ir.NodeType.DelegateType:
	case ir.NodeType.AAType:
	case ir.NodeType.Interface:
		return buildConstantNull(l, t);
	case ir.NodeType.Struct:
	case ir.NodeType.Union:
		auto _struct = cast(ir.Aggregate) t;
		ir.Exp[] exps;
		foreach (n; _struct.members.nodes) {
			auto var = cast(ir.Variable) n;
			if (var is null || var is _struct.typeInfo) {
				continue;
			}
			exps ~= getDefaultInit(l, lp, current, var.type);
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
