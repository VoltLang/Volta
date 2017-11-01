/*#D*/
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.copy;

import watt.text.format : format;

import ir = volta.ir;
import volt.errors;
import volt.ir.util;
import volta.util.dup;
import volta.ir.location;


ir.AccessExp copy(ir.AccessExp old)
{
	auto ae = new ir.AccessExp();
	ae.loc = old.loc;
	ae.child = copyExp(old.child);
	ae.field = old.field;
	ae.aggregate = old.aggregate;
	return ae;
}

ir.Constant copy(ir.Constant cnst)
{
	auto c = new ir.Constant();
	c.loc = cnst.loc;
	c.type = cnst.type !is null ? copyType(cnst.type) : null;
	c.u._ulong = cnst.u._ulong;
	c._string = cnst._string;
	c.isNull = cnst.isNull;
	c.arrayData = cnst.arrayData.idup();
	c.fromEnum = cnst.fromEnum;
	return c;
}

ir.BlockStatement copy(ir.BlockStatement bs)
{
	auto b = new ir.BlockStatement();
	b.loc = bs.loc;
	b.statements = new ir.Node[](bs.statements.length);
	foreach (i, stmt; bs.statements) {
		b.statements[i] = copyNode(stmt);
	}

	return b;
}

ir.ReturnStatement copy(ir.ReturnStatement rs)
{
	auto r = new ir.ReturnStatement();
	r.loc = rs.loc;
	if (rs.exp !is null) {
		r.exp = copyExp(rs.exp);
	}
	return r;
}

ir.BinOp copy(ir.BinOp bo)
{
	auto b = new ir.BinOp();
	b.loc = bo.loc;
	b.op = bo.op;
	b.left = copyExp(bo.left);
	b.right = copyExp(bo.right);
	return b;
}

ir.IdentifierExp copy(ir.IdentifierExp ie)
{
	auto i = new ir.IdentifierExp();
	i.loc = ie.loc;
	i.globalLookup = ie.globalLookup;
	i.value = ie.value;
	return i;
}

ir.TokenExp copy(ir.TokenExp te)
{
	auto newte = new ir.TokenExp(te.type);
	newte.loc = te.loc;
	return newte;
}

ir.TypeExp copy(ir.TypeExp te)
{
	auto newte = new ir.TypeExp();
	newte.loc = te.loc;
	newte.type = copyType(te.type);
	return newte;
}

ir.StoreExp copy(ir.StoreExp se)
{
	auto newse = new ir.StoreExp();
	newse.loc = se.loc;
	newse.store = se.store;
	newse.idents = se.idents.dup();
	return newse;
}

ir.ArrayLiteral copy(ir.ArrayLiteral ar)
{
	auto newar = new ir.ArrayLiteral();
	newar.loc = ar.loc;
	if (ar.type !is null)
		newar.type = copyType(ar.type);
	newar.exps = new ir.Exp[](ar.exps.length);
	foreach (i, value; ar.exps) {
		newar.exps[i] = copyExp(value);
	}
	return newar;
}

ir.ExpReference copy(ir.ExpReference er)
{
	auto newer = new ir.ExpReference();
	newer.loc = er.loc;
	newer.idents = er.idents.dup();
	newer.decl = er.decl;
	newer.rawReference = er.rawReference;
	newer.doNotRewriteAsNestedLookup = er.doNotRewriteAsNestedLookup;
	newer.isSuperOrThisCall = er.isSuperOrThisCall;
	return newer;
}

ir.Identifier copy(ir.Identifier ident)
{
	auto n = new ir.Identifier();
	n.loc = ident.loc;
	n.value = ident.value;
	return n;
}

ir.Postfix copy(ir.Postfix pfix)
{
	auto newpfix = new ir.Postfix();
	newpfix.loc = pfix.loc;
	newpfix.op = pfix.op;
	newpfix.child = copyExp(pfix.child);
	newpfix.arguments = new ir.Exp[](pfix.arguments.length);
	foreach (i, arg; pfix.arguments) {
		newpfix.arguments[i] = copyExp(arg);
	}
	newpfix.argumentTags =
		new ir.Postfix.TagKind[](pfix.argumentTags.length);
	foreach (i, argTag; pfix.argumentTags) {
		newpfix.argumentTags[i] = argTag;
	}
	if (pfix.identifier !is null) {
		newpfix.identifier = copy(pfix.identifier);
	}
	if (pfix.memberFunction !is null) {
		newpfix.memberFunction = copy(pfix.memberFunction);
	}
	newpfix.isImplicitPropertyCall = pfix.isImplicitPropertyCall;
	return newpfix;
}

ir.Unary copy(ir.Unary unary)
{
	auto newunary = new ir.Unary();
	newunary.loc = unary.loc;
	newunary.op = unary.op;
	newunary.value = unary.value is null ? null : copyExp(unary.value);
	newunary.hasArgumentList = unary.hasArgumentList;
	newunary.fullShorthand = unary.fullShorthand;
	if (unary.type !is null) {
		newunary.type = copyType(unary.type);
	}
	newunary.argumentList = new ir.Exp[](unary.argumentList.length);
	foreach (i, arg; unary.argumentList) {
		newunary.argumentList[i] = copyExp(arg);
	}
	if (unary.dupBeginning !is null) {
		newunary.dupBeginning = copyExp(unary.dupBeginning);
		newunary.dupEnd = copyExp(unary.dupEnd);
	}
	return newunary;
}

ir.PropertyExp copy(ir.PropertyExp old)
{
	auto prop = new ir.PropertyExp();
	prop.loc = old.loc;
	prop.getFn  = old.getFn;
	prop.setFns = old.setFns;
	if (old.child !is null) {
		prop.child = copyExp(old.child);
	}
	if (old.identifier !is null) {
		prop.identifier = copy(old.identifier);
	}
	return prop;
}

/*
 *
 * Type copy
 *
 */


ir.PrimitiveType copy(ir.PrimitiveType old)
{
	auto pt = new ir.PrimitiveType(old.type);
	pt.loc = old.loc;
	return pt;
}

ir.PointerType copy(ir.PointerType old)
{
	auto pt = new ir.PointerType(copyType(old.base));
	pt.loc = old.loc;
	return pt;
}

ir.ArrayType copy(ir.ArrayType old)
{
	auto at = new ir.ArrayType(copyType(old.base));
	at.loc = old.loc;
	return at;
}

ir.StaticArrayType copy(ir.StaticArrayType old)
{
	auto sat = new ir.StaticArrayType();
	sat.loc = old.loc;
	sat.base = copyType(old.base);
	sat.length = old.length;
	return sat;
}

ir.AAType copy(ir.AAType old)
{
	auto aa = new ir.AAType();
	aa.loc = old.loc;
	aa.value = copyType(old.value);
	aa.key = copyType(old.key);
	return aa;
}

ir.FunctionType copy(ir.FunctionType old)
{
	auto ft = new ir.FunctionType(old);
	ft.loc = old.loc;
	ft.ret = copyType(old.ret);
	panicAssert(old, old.params.length == old.isArgRef.length && old.params.length == old.isArgOut.length);
	ft.params = new ir.Type[](old.params.length);
	ft.isArgOut = new bool[](old.isArgOut.length);
	ft.isArgRef = new bool[](old.isArgRef.length);
	foreach (i, ptype; old.params) {
		ft.params[i] = copyType(ptype);
		ft.isArgOut[i] = old.isArgOut[i];
		ft.isArgRef[i] = old.isArgRef[i];
	}
	return ft;
}

ir.DelegateType copy(ir.DelegateType old)
{
	auto dgt = new ir.DelegateType(old);
	dgt.loc = old.loc;
	dgt.ret = copyType(old.ret);
	panicAssert(old, old.params.length == old.isArgRef.length && old.params.length == old.isArgOut.length);
	dgt.params = new ir.Type[](old.params.length);
	dgt.isArgOut = new bool[](old.isArgOut.length);
	dgt.isArgRef = new bool[](old.isArgRef.length);
	foreach (i, ptype; old.params) {
		dgt.params[i] = copyType(ptype);
		dgt.isArgOut[i] = old.isArgOut[i];
		dgt.isArgRef[i] = old.isArgRef[i];
	}
	return dgt;
}

ir.StorageType copy(ir.StorageType old)
{
	auto st = new ir.StorageType();
	st.loc = old.loc;
	if (old.base !is null) {
		st.base = copyType(old.base);
	}
	st.type = old.type;
	return st;
}

ir.TypeReference copy(ir.TypeReference old)
{
	auto tr = new ir.TypeReference();
	tr.loc = old.loc;
	tr.id = copy(old.id);
	if (old.type !is null) {
		tr.type = old.type;  // This is okay, as TR are meant to wrap the same type instance.
	}
	return tr;
}

ir.NullType copy(ir.NullType old)
{
	auto nt = new ir.NullType();
	nt.loc = old.loc;
	return nt;
}

ir.Typeid copy(ir.Typeid old)
{
	auto tid = new ir.Typeid();
	tid.loc = old.loc;
	if (old.exp !is null) {
		tid.exp = copyExp(old.exp);
	}
	if (old.type !is null) {
		tid.type = copyType(old.type);
	}
	return tid;
}

ir.AutoType copy(ir.AutoType old)
{
	auto at = new ir.AutoType();
	at.loc = old.loc;
	at.isForeachRef = old.isForeachRef;
	if (old.explicitType !is null) {
		at.explicitType = copyType(old.explicitType);
	}
	addStorage(at, old);
	return at;
}

ir.BuiltinExp copy(ir.BuiltinExp old)
{
	auto type = copyType(old.type);
	auto exps = new ir.Exp[](old.children.length);
	foreach (i, oldExp; old.children) {
		exps[i] = copyExp(oldExp);
	}
	auto builtin = new ir.BuiltinExp(old.kind, type, exps);
	builtin.loc = old.loc;
	return builtin;
}

ir.RunExp copy(ir.RunExp old)
{
	auto re = new ir.RunExp();
	re.loc = old.loc;
	re.child = copyExp(old.child);
	return re;
}

ir.ComposableString copy(ir.ComposableString old)
{
	auto cs = new ir.ComposableString(old);
	cs.loc = old.loc;
	return cs;
}

/*
 *
 * Helpers.
 *
 */


ir.QualifiedName copy(ir.QualifiedName old)
{
	auto q = new ir.QualifiedName();
	q.loc = old.loc;
	q.identifiers = new ir.Identifier[](old.identifiers.length);
	foreach (i, oldId; old.identifiers) {
		q.identifiers[i] = copy(oldId);
	}
	return q;
}

/*!
 * Helper function that takes care of up
 * casting the return from copyDeep.
 */
ir.Type copyType(ir.Type t)
{
	ir.Type newt;
	switch (t.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		newt = copy(cast(ir.PrimitiveType)t);
		break;
	case PointerType:
		newt = copy(cast(ir.PointerType)t);
		break;
	case ArrayType:
		newt = copy(cast(ir.ArrayType)t);
		break;
	case StaticArrayType:
		newt = copy(cast(ir.StaticArrayType)t);
		break;
	case AAType:
		newt = copy(cast(ir.AAType)t);
		break;
	case FunctionType:
		newt = copy(cast(ir.FunctionType)t);
		break;
	case DelegateType:
		newt = copy(cast(ir.DelegateType)t);
		break;
	case StorageType:
		newt = copy(cast(ir.StorageType)t);
		break;
	case TypeReference:
		newt = copy(cast(ir.TypeReference)t);
		break;
	case NullType:
		newt = copy(cast(ir.NullType)t);
		break;
	case Interface:
	case Struct:
	case Class:
	case Enum:
		throw panic(/*#ref*/t.loc, "can't copy aggregate types");
	default:
		throw panicUnhandled(t, ir.nodeToString(t));
	}
	addStorage(newt, t);
	return newt;
}

/*!
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

ir.Exp copyExp(ref in Location loc, ir.Exp exp)
{
	auto e = copyExp(exp);
	e.loc = loc;
	return e;
}

/*!
 * Copies a node and all its children nodes.
 */
ir.Node copyNode(ir.Node n)
{
	final switch (n.nodeType) with (ir.NodeType) {
	case Invalid:
		auto msg = format("cannot copy '%s'", ir.nodeToString(n));
		throw panic(/*#ref*/n.loc, msg);
	case NonVisiting:
		assert(false, "non-visiting node");
	case AccessExp:
		auto ae = cast(ir.AccessExp)n;
		return copy(ae);
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
	case StoreExp:
		auto se = cast(ir.StoreExp)n;
		return copy(se);
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
	case PropertyExp:
		auto pe = cast(ir.PropertyExp)n;
		return copy(pe);
	case Unary:
		auto unary = cast(ir.Unary)n;
		return copy(unary);
	case Typeid:
		auto tid = cast(ir.Typeid)n;
		return copy(tid);
	case AutoType:
		auto at = cast(ir.AutoType)n;
		return copy(at);
	case BuiltinExp:
		auto bi = cast(ir.BuiltinExp)n;
		return copy(bi);
	case RunExp:
		auto re = cast(ir.RunExp)n;
		return copy(re);
	case ComposableString:
		auto cs = cast(ir.ComposableString)n;
		return copy(cs);
	case Enum:
	case StatementExp:
	case PrimitiveType:
	case TypeReference:
	case PointerType:
	case NullType:
	case ArrayType:
	case StaticArrayType:
	case AmbiguousArrayType:
	case AAType:
	case AAPair:
	case FunctionType:
	case DelegateType:
	case StorageType:
	case TypeOf:
	case Struct:
	case Class:
	case Interface:
	case AliasStaticIf:
		auto t = cast(ir.Type)n;
		return copyTypeSmart(/*#ref*/t.loc, t);  // @todo do correctly.
	case QualifiedName:
	case Identifier:
	case Module:
	case TopLevelBlock:
	case Import:
	case Unittest:
	case Union:
	case Attribute:
	case MixinTemplate:
	case MixinFunction:
	case Condition:
	case ConditionTopLevel:
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
	case ConditionStatement:
	case MixinStatement:
	case AssertStatement:
	case Ternary:
	case AssocArray:
	case Assert:
	case StringImport:
	case IsExp:
	case FunctionLiteral:
	case StructLiteral:
	case UnionLiteral:
	case ClassLiteral:
	case EnumDeclaration:
	case FunctionSet:
	case FunctionSetType:
	case VaArgExp:
	case NoType:
	case TemplateInstance:
	case TemplateDefinition:
		goto case Invalid;
	}
}
