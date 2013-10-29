// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.copy;

import std.conv : to;
import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.token.location;

import volt.errors;


ir.Constant copy(ir.Constant cnst)
{
	auto c = new ir.Constant();
	c.location = cnst.location;
	c.type = cnst.type !is null ? copyType(cnst.type) : null;
	c._ulong = cnst._ulong;
	c._string = cnst._string;
	c.isNull = cnst.isNull;
	c.arrayData = cnst.arrayData.dup;
	return c;
}

ir.BlockStatement copy(ir.BlockStatement bs)
{
	auto b = new ir.BlockStatement();
	b.location = bs.location;
	b.statements = bs.statements;

	foreach (ref stat; b.statements) {
		stat = copyNode(stat);
	}

	return b;
}

ir.ReturnStatement copy(ir.ReturnStatement rs)
{
	auto r = new ir.ReturnStatement();
	r.location = rs.location;
	r.exp = copyExp(rs.exp);
	return r;
}

ir.BinOp copy(ir.BinOp bo)
{
	auto b = new ir.BinOp();
	b.location = bo.location;
	b.op = bo.op;
	b.left = copyExp(bo.left);
	b.right = copyExp(bo.right);
	return b;
}

ir.IdentifierExp copy(ir.IdentifierExp ie)
{
	auto i = new ir.IdentifierExp();
	i.location = ie.location;
	i.globalLookup = ie.globalLookup;
	i.value = ie.value;
	i.type = copyNode(ie.type);
	return i;
}

ir.TokenExp copy(ir.TokenExp te)
{
	auto newte = new ir.TokenExp(te.type);
	newte.location = te.location;
	return newte;
}


ir.TypeExp copy(ir.TypeExp te)
{
	auto newte = new ir.TypeExp();
	newte.location = te.location;
	newte.type = copyType(te.type);
	return newte;
}

ir.ArrayLiteral copy(ir.ArrayLiteral ar)
{
	auto newar = new ir.ArrayLiteral();
	newar.location = ar.location;
	if (ar.type !is null)
		newar.type = copyType(ar.type);
	newar.values = ar.values.dup;
	foreach (ref value; ar.values) {
		value = copyExp(value);
	}
	return newar;
}

ir.ExpReference copy(ir.ExpReference er)
{
	auto newer = new ir.ExpReference();
	newer.location = er.location;
	newer.idents = er.idents.dup;
	newer.decl = er.decl;
	newer.rawReference = er.rawReference;
	newer.doNotRewriteAsNestedLookup = er.doNotRewriteAsNestedLookup;
	return newer;
}

ir.Identifier copy(ir.Identifier ident)
{
	auto n = new ir.Identifier();
	n.location = ident.location;
	n.value = ident.value;
	return n;
}

ir.Postfix copy(ir.Postfix pfix)
{
	auto newpfix = new ir.Postfix();
	newpfix.location = pfix.location;
	newpfix.op = pfix.op;
	newpfix.child = copyExp(pfix.child);
	foreach (arg; pfix.arguments) {
		newpfix.arguments ~= copyExp(arg);
	}
	foreach (argTag; pfix.argumentTags) {
		newpfix.argumentTags ~= argTag;
	}
	if (pfix.identifier !is null) {
		newpfix.identifier = copy(pfix.identifier);
	}
	if (newpfix.memberFunction !is null) {
		newpfix.memberFunction = copy(pfix.memberFunction);
	}
	newpfix.isImplicitPropertyCall = pfix.isImplicitPropertyCall;
	return newpfix;
}

/*
 *
 * Type copy
 *
 */


ir.PrimitiveType copy(ir.PrimitiveType old)
{
	auto pt = new ir.PrimitiveType(old.type);
	pt.location = old.location;
	return pt;
}

ir.PointerType copy(ir.PointerType old)
{
	auto pt = new ir.PointerType(copyType(old.base));
	pt.location = old.location;
	return pt;
}

ir.ArrayType copy(ir.ArrayType old)
{
	auto at = new ir.ArrayType(copyType(old.base));
	at.location = old.location;
	return at;
}

ir.StaticArrayType copy(ir.StaticArrayType old)
{
	auto sat = new ir.StaticArrayType();
	sat.location = old.location;
	sat.base = copyType(old.base);
	sat.length = old.length;
	return sat;
}

ir.AAType copy(ir.AAType old)
{
	auto aa = new ir.AAType();
	aa.location = old.location;
	aa.value = copyType(old.value);
	aa.key = copyType(old.key);
	return aa;
}

ir.FunctionType copy(ir.FunctionType old)
{
	auto ft = new ir.FunctionType(old);
	ft.location = old.location;
	ft.ret = copyType(old.ret);
	foreach(ref ptype; ft.params) {
		ptype = copyType(ptype);
	}
	return ft;
}

ir.DelegateType copy(ir.DelegateType old)
{
	auto dg = new ir.DelegateType(old);
	dg.location = old.location;
	dg.ret = copyType(old.ret);
	foreach(ref ptype; dg.params) {
		ptype = copyType(ptype);
	}
	return dg;
}

ir.StorageType copy(ir.StorageType old)
{
	auto st = new ir.StorageType();
	st.location = old.location;
	if (old.base !is null) {
		st.base = copyType(old.base);
	}
	st.type = old.type;
	st.isCanonical = old.isCanonical;
	return st;
}

ir.TypeReference copy(ir.TypeReference old)
{
	auto tr = new ir.TypeReference();
	tr.location = old.location;
	tr.id = copy(old.id);
	if (old.type !is null) {
		assert(false);
	}
	return tr;
}


/*
 *
 * Helpers.
 *
 */


ir.QualifiedName copy(ir.QualifiedName old)
{
	auto q = new ir.QualifiedName();
	q.location = old.location;
	q.identifiers = old.identifiers;
	foreach (ref oldId; q.identifiers) {
		auto id = new ir.Identifier(oldId.value);
		id.location = old.location;
		oldId = id;
	}
	return q;
}

/**
 * Helper function that takes care of up
 * casting the return from copyDeep.
 */
ir.Type copyType(ir.Type t)
{
	switch (t.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		return copy(cast(ir.PrimitiveType)t);
	case PointerType:
		return copy(cast(ir.PointerType)t);
	case ArrayType:
		return copy(cast(ir.ArrayType)t);
	case StaticArrayType:
		return copy(cast(ir.StaticArrayType)t);
	case AAType:
		return copy(cast(ir.AAType)t);
	case FunctionType:
		return copy(cast(ir.FunctionType)t);
	case DelegateType:
		return copy(cast(ir.DelegateType)t);
	case StorageType:
		return copy(cast(ir.StorageType)t);
	case TypeReference:
		return copy(cast(ir.TypeReference)t);
	case Interface:
	case Struct:
	case Class:
	case UserAttribute:
	case Enum:
		throw panic(t.location, "can't copy aggregate types");
	default:
		assert(false);
	}
}

/**
 * Helper function that takes care of up
 * casting the return from copyDeep.
 */
ir.Exp copyExp(ir.Exp exp)
{
	auto n = copyNode(exp);
	exp = cast(ir.Exp)n;
	assert(exp !is null);
	return exp;
}

ir.Exp copyExp(Location location, ir.Exp exp)
{
	auto e = copyExp(exp);
	e.location = location;
	return e;
}

/**
 * Copies a node and all its children nodes.
 */
ir.Node copyNode(ir.Node n)
{
	final switch (n.nodeType) with (ir.NodeType) {
	case Invalid:
		auto msg = format("invalid node '%s'", to!string(n.nodeType));
		assert(false, msg);
	case NonVisiting:
		assert(false, "non-visiting node");
	case Constant:
		auto c = cast(ir.Constant)n;
		return copy(c);
	case BlockStatement:
		auto bs = cast(ir.BlockStatement)n;
		return copy(bs);
	case ReturnStatement:
		auto rs = cast(ir.ReturnStatement)n;
		return copy(rs);
	case BinOp:
		auto bo = cast(ir.BinOp)n;
		return copy(bo);
	case IdentifierExp:
		auto ie = cast(ir.IdentifierExp)n;
		return copy(ie);
	case TypeExp:
		auto te = cast(ir.TypeExp)n;
		return copy(te);
	case ArrayLiteral:
		auto ar = cast(ir.ArrayLiteral)n;
		return copy(ar);
	case TokenExp:
		auto te = cast(ir.TokenExp)n;
		return copy(te);
	case ExpReference:
		auto er = cast(ir.ExpReference)n;
		return copy(er);
	case Postfix:
		auto pfix = cast(ir.Postfix)n;
		return copy(pfix);
	case StatementExp:
	case PrimitiveType:
	case TypeReference:
	case PointerType:
	case NullType:
	case ArrayType:
	case StaticArrayType:
	case AAType:
	case AAPair:
	case FunctionType:
	case DelegateType:
	case StorageType:
	case TypeOf:
	case Struct:
	case Class:
	case Interface:
		auto t = cast(ir.Type)n;
		return copyTypeSmart(t.location, t);  /// @todo do correctly.
	case QualifiedName:
	case Identifier:
	case Module:
	case TopLevelBlock:
	case Import:
	case Unittest:
	case Union:
	case Enum:
	case Attribute:
	case StaticAssert:
	case MixinTemplate:
	case MixinFunction:
	case UserAttribute:
	case EmptyTopLevel:
	case Condition:
	case ConditionTopLevel:
	case FunctionDecl:
	case FunctionBody:
	case Variable:
	case Alias:
	case Function:
	case FunctionParam:
	case AsmStatement:
	case IfStatement:
	case WhileStatement:
	case DoStatement:
	case ForStatement:
	case ForeachStatement:
	case LabelStatement:
	case ExpStatement:
	case SwitchStatement:
	case SwitchCase:
	case ContinueStatement:
	case BreakStatement:
	case GotoStatement:
	case WithStatement:
	case SynchronizedStatement:
	case TryStatement:
	case ThrowStatement:
	case ScopeStatement:
	case PragmaStatement:
	case EmptyStatement:
	case ConditionStatement:
	case MixinStatement:
	case AssertStatement:
	case Comma:
	case Ternary:
	case Unary:
	case AssocArray:
	case Assert:
	case StringImport:
	case Typeid:
	case IsExp:
	case TraitsExp:
	case TemplateInstanceExp:
	case FunctionLiteral:
	case StructLiteral:
	case ClassLiteral:
	case EnumDeclaration:
	case FunctionSet:
	case FunctionSetType:
	case VaArgExp:
		goto case Invalid;
	}
}
