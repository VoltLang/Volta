// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.copy;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.errors;
import volt.ir.util;
import volt.token.location;


ir.Constant copy(ir.Constant cnst)
{
	auto c = new ir.Constant();
	c.location = cnst.location;
	c.type = cnst.type !is null ? copyType(cnst.type) : null;
	c.u._ulong = cnst.u._ulong;
	c._string = cnst._string;
	c.isNull = cnst.isNull;
	version (Volt) {
		c.arrayData = new cnst.arrayData[0 .. $];
	} else {
		c.arrayData = cnst.arrayData.idup;
	}
	return c;
}

ir.BlockStatement copy(ir.BlockStatement bs)
{
	auto b = new ir.BlockStatement();
	b.location = bs.location;
	b.statements = new ir.Node[](bs.statements.length);
	foreach (i, stmt; bs.statements) {
		b.statements[i] = copyNode(stmt);
	}

	return b;
}

ir.ReturnStatement copy(ir.ReturnStatement rs)
{
	auto r = new ir.ReturnStatement();
	r.location = rs.location;
	if (rs.exp !is null) {
		r.exp = copyExp(rs.exp);
	}
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

ir.StoreExp copy(ir.StoreExp se)
{
	auto newse = new ir.StoreExp();
	newse.location = se.location;
	newse.store = se.store;
	version (Volt) {
		newse.idents = new se.idents[0 .. $];
	} else {
		newse.idents = se.idents.dup;
	}
	return newse;
}

ir.ArrayLiteral copy(ir.ArrayLiteral ar)
{
	auto newar = new ir.ArrayLiteral();
	newar.location = ar.location;
	if (ar.type !is null)
		newar.type = copyType(ar.type);
	newar.values = new ir.Exp[](ar.values.length);
	foreach (i, value; ar.values) {
		newar.values[i] = copyExp(value);
	}
	return newar;
}

ir.ExpReference copy(ir.ExpReference er)
{
	auto newer = new ir.ExpReference();
	newer.location = er.location;
	version (Volt) {
		newer.idents = new er.idents[0 .. $];
	} else {
		newer.idents = er.idents.dup;
	}
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
	if (newpfix.memberFunction !is null) {
		newpfix.memberFunction = copy(pfix.memberFunction);
	}
	newpfix.isImplicitPropertyCall = pfix.isImplicitPropertyCall;
	return newpfix;
}

ir.Unary copy(ir.Unary unary)
{
	auto newunary = new ir.Unary();
	newunary.location = unary.location;
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
	if (unary.dupName !is null) {
		newunary.dupName = copy(unary.dupName);
		newunary.dupBeginning = copyExp(unary.dupBeginning);
		newunary.dupEnd = copyExp(unary.dupEnd);
	}
	return newunary;
}

ir.PropertyExp copy(ir.PropertyExp old)
{
	auto prop = new ir.PropertyExp();
	prop.location = old.location;
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
	auto dg = new ir.DelegateType(old);
	dg.location = old.location;
	dg.ret = copyType(old.ret);
	panicAssert(old, old.params.length == old.isArgRef.length && old.params.length == old.isArgOut.length);
	dg.params = new ir.Type[](old.params.length);
	dg.isArgOut = new bool[](old.isArgOut.length);
	dg.isArgRef = new bool[](old.isArgRef.length);
	foreach (i, ptype; old.params) {
		dg.params[i] = copyType(ptype);
		dg.isArgOut[i] = old.isArgOut[i];
		dg.isArgRef[i] = old.isArgRef[i];
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
	return st;
}

ir.TypeReference copy(ir.TypeReference old)
{
	auto tr = new ir.TypeReference();
	tr.location = old.location;
	tr.id = copy(old.id);
	if (old.type !is null) {
		tr.type = old.type;  // This is okay, as TR are meant to wrap the same type instance.
	}
	return tr;
}

ir.NullType copy(ir.NullType old)
{
	auto nt = new ir.NullType();
	nt.location = old.location;
	return nt;
}

ir.Typeid copy(ir.Typeid old)
{
	auto tid = new ir.Typeid();
	tid.location = old.location;
	if (old.exp !is null) {
		tid.exp = copyExp(old.exp);
	}
	if (old.type !is null) {
		tid.type = copyType(old.type);
	}
	if (old.ident !is null) {
		version (Volt) {
			tid.ident = new old.ident[0 .. $];
		} else {
			tid.ident = tid.ident.dup;
		}
	}
	return tid;
}

ir.AutoType copy(ir.AutoType old)
{
	auto at = new ir.AutoType();
	at.location = old.location;
	at.isForeachRef = old.isForeachRef;
	if (old.explicitType !is null) {
		at.explicitType = copyType(old.explicitType);
	}
	addStorage(at, old);
	return at;
}

/*
 *
 * Other Copy
 *
 */
ir.Enum copy(ir.Enum old)
{
	auto e = new ir.Enum();
	e.location = old.location;
	e.mangledName = old.mangledName;
	e.access = old.access;
	e.name = old.name;
	e.myScope = copy(old.myScope);
	e.members = new ir.EnumDeclaration[](old.members.length);
	foreach (i, member; old.members) {
		e.members[i] = copy(member);
	}
	e.base = copyType(old.base);
	e.isResolved = old.isResolved;
	return e;
}

ir.StatementExp copy(ir.StatementExp old)
{
	auto se = new ir.StatementExp();
	se.location = old.location;
	se.exp = copyExp(old.exp);
	if (se.originalExp !is null) {
		se.originalExp = copyExp(old.originalExp);
	}
	return se;
}

ir.TypeOf copy(ir.TypeOf old)
{
	auto to = new ir.TypeOf();
	to.location = old.location;
	to.mangledName = old.mangledName;
	to.exp = copyExp(old.exp);
	return to;
}

ir.Struct copy(ir.Struct old)
{
	auto s = new ir.Struct();
	s.location = old.location;
	copyAggregate(s, old);
	if (old.loweredNode !is null) {
		s.loweredNode = copyNode(old.loweredNode);
	}
	return s;
}

ir.Class copy(ir.Class old)
{
	auto c = new ir.Class();
	c.location = old.location;
	copyAggregate(c, old);
	if (old.parent !is null) {
		c.parent = copy(old.parent);
	}
	c.interfaces = new ir.QualifiedName[](old.interfaces.length);
	foreach (i, iface; old.interfaces) {
		c.interfaces[i] = copy(iface);
	}
	c.userConstructors = new ir.Function[](old.userConstructors.length);
	foreach (i, ctor; old.userConstructors) {
		c.userConstructors[i] = copy(ctor);
	}
	c.vtableStruct = copy(old.vtableStruct);
	c.vtableVariable = copy(old.vtableVariable);
	c.ifaceVariables = new ir.Variable[](old.ifaceVariables.length);
	foreach (i, iv; old.ifaceVariables) {
		c.ifaceVariables[i] = copy(iv);
	}
	c.initVariable = copy(old.initVariable);
	if (old.parentClass !is null) {
		c.parentClass = copy(old.parentClass);
	}
	c.parentInterfaces = new ir._Interface[](old.parentInterfaces.length);
	foreach (i, piface; old.parentInterfaces) {
		c.parentInterfaces[i] = copy(piface);
	}
	c.interfaceOffsets = new old.interfaceOffsets[0 .. $];
	c.layoutStruct = copy(old.layoutStruct);
	c.isObject = old.isObject;
	c.isAbstract = old.isAbstract;
	return c;
}

ir._Interface copy(ir._Interface old)
{
	auto ifa = new ir._Interface();
	ifa.location = old.location;
	ifa.interfaces = new ir.QualifiedName[](old.interfaces.length);
	foreach (i, iface; old.interfaces) {
		ifa.interfaces[i] = copy(iface);
	}
	ifa.parentInterfaces = new ir._Interface[](old.parentInterfaces.length);
	foreach (i, piface; old.parentInterfaces) {
		ifa.parentInterfaces[i] = copy(piface);
	}
	if (old.layoutStruct !is null) {
		ifa.layoutStruct = copy(old.layoutStruct);
	}
	return ifa;
}

ir.Module copy(ir.Module old)
{
	auto nm = new ir.Module();
	nm.location = old.location;
	nm.name = copy(old.name);
	nm.children = copy(old.children);
	if (old.myScope !is null) {
		nm.myScope = copy(old.myScope);
	}
	nm.hasPhase1 = old.hasPhase1;
	nm.hasPhase2 = old.hasPhase2;
	nm.gathered = old.gathered;
	return nm;
}

ir.TopLevelBlock copy(ir.TopLevelBlock old)
{
	auto tld = new ir.TopLevelBlock();
	tld.location = old.location;
	tld.nodes = new ir.Node[](old.nodes.length);
	foreach (i, node; old.nodes) {
		tld.nodes[i] = copyNode(node);
	}
	return tld;
}

ir.Import copy(ir.Import old)
{
	auto imp = new ir.Import();
	imp.location = old.location;
	imp.access = old.access;
	imp.isStatic = old.isStatic;
	imp.name = copy(old.name);
	if (old.bind !is null) {
		imp.bind = copy(old.bind);
	}
	imp.aliases = new ir.Identifier[][](old.aliases.length);
	foreach (i, a; old.aliases) {
		ir.Identifier[2] idents;
		idents[0] = copy(a[0]);
		idents[1] = copy(a[1]);
		imp.aliases[i] = idents;
	}
	// Don't copy the module, filled in by the import resolver.
	// Copying the module would result in a infinite recurision.
	imp.targetModule = null;
	return imp;
}

ir.Unittest copy(ir.Unittest old)
{
	auto u = new ir.Unittest();
	u.location = old.location;
	u._body = copy(old._body);
	return u;
}

ir.Union copy(ir.Union old)
{
	auto u = new ir.Union();
	u.location = old.location;
	copyAggregate(u, old);
	u.totalSize = old.totalSize;
	return u;
}

ir.Attribute copy(ir.Attribute old)
{
	auto a = new ir.Attribute();
	a.location = old.location;
	a.kind = old.kind;
	a.members = copy(old.members);
	if (old.userAttributeName !is null) {
		a.userAttributeName = copy(old.userAttributeName);
	}
	a.arguments = new ir.Exp[](old.arguments.length);
	foreach (i, arg; old.arguments) {
		a.arguments[i] = copyExp(arg);
	}
	if (old.userAttribute !is null) {
		a.userAttribute = copy(old.userAttribute);
	}
	a.alignAmount = old.alignAmount;
	return a;
}

ir.StaticAssert copy(ir.StaticAssert old)
{
	auto sa = new ir.StaticAssert();
	sa.location = old.location;
	sa.exp = copyExp(old.exp);
	if (old.message !is null) {
		sa.message = copyExp(old.message);
	}
	return sa;
}

ir.MixinTemplate copy(ir.MixinTemplate old)
{
	auto mt = new ir.MixinTemplate();
	mt.location = old.location;
	mt.name = old.name;
	if (old.raw !is null) {
		mt.raw = copy(old.raw);
	}
	return mt;
}

ir.MixinFunction copy(ir.MixinFunction old)
{
	auto mf = new ir.MixinFunction();
	mf.location = old.location;
	mf.name = old.name;
	if (old.raw !is null) {
		mf.raw = copy(old.raw);
	}
	return mf;
}

ir.UserAttribute copy(ir.UserAttribute old)
{
	auto ua = new ir.UserAttribute();
	ua.location = old.location;
	ua.mangledName = old.mangledName;
	ua.name = old.name;
	ua.fields = new ir.Variable[](old.fields.length);
	foreach (i, filed; old.fields) {
		ua.fields[i] = copy(filed);
	}
	if (old.myScope !is null) {
		ua.myScope = copy(old.myScope);
	}
	return ua;
}

ir.Condition copy(ir.Condition old)
{
	auto c = new ir.Condition();
	c.location = old.location;
	c.kind = old.kind;
	c.exp = copyExp(old.exp);
	return c;
}

ir.ConditionTopLevel copy(ir.ConditionTopLevel old)
{
	auto ctl = new ir.ConditionTopLevel();
	ctl.location = old.location;
	ctl.condition = copy(old.condition);
	ctl.elsePresent = old.elsePresent;
	ctl.members = copy(old.members);
	if (ctl._else !is null) {
		ctl._else = copy(old._else);
	}
	return ctl;
}

ir.Variable copy(ir.Variable old)
{
	auto v = new ir.Variable();
	v.location = old.location;
	copyDeclaration(v, old);
	v.access = old.access;
	v.type = copyType(old.type);
	v.name = old.name;
	v.mangledName = old.mangledName;
	if (old.assign !is null) {
		v.assign = copyExp(old.assign);
	}
	v.storage = old.storage;
	v.linkage = old.linkage;
	v.isResolved = old.isResolved;
	v.isWeakLink = old.isWeakLink;
	v.isExtern = old.isExtern;
	v.isOut = old.isOut;
	v.hasBeenDeclared = old.hasBeenDeclared;
	v.useBaseStorage = old.useBaseStorage;
	v.specialInitValue = old.specialInitValue;
	return v;
}

ir.Alias copy(ir.Alias old)
{
	auto a = new ir.Alias();
	a.location = old.location;
	a.access = old.access;
	a.isResolved = old.isResolved;
	a.name = old.name;
	a.type = copyType(old.type);
	a.id = copy(old.id);
	a.store = old.store;
	return a;
}

ir.Function copy(ir.Function old)
{
	auto f = new ir.Function();
	f.location = old.location;
	f.access = old.access;
	if (old.myScope !is null) {
		f.myScope = copy(old.myScope);
	}
	f.kind = old.kind;
	f.type = copy(old.type);
	f.params = new ir.FunctionParam[](old.params.length);
	foreach (i, param; old.params) {
		f.params[i] = copy(param);
		f.params[i].fn = f;
	}
	f.nestedFunctions = new ir.Function[](old.nestedFunctions.length);
	foreach (i, func; old.nestedFunctions) {
		f.nestedFunctions[i] = copy(func);
	}
	f.name = old.name;
	f.mangledName = old.mangledName;
	f.outParameter = old.outParameter;
	if (old.inContract !is null) {
		f.inContract = copy(old.inContract);
	}
	if (old.outContract !is null) {
		f.outContract = copy(old.outContract);
	}
	if (old._body !is null) {
		f._body = copy(old._body);
	}
	if (old.thisHiddenParameter !is null) {
		f.thisHiddenParameter = copy(old.thisHiddenParameter);
	}
	if (old.nestedHiddenParameter !is null) {
		f.nestedHiddenParameter = copy(old.nestedHiddenParameter);
	}
	if (old.nestedVariable !is null) {
		f.nestedVariable = copy(old.nestedVariable);
	}
	f.renamedVariables = new ir.Variable[](old.renamedVariables.length);
	foreach (i, var; old.renamedVariables) {
		f.renamedVariables[i] = copy(var);
	}
	if (old.nestStruct !is null) {
		f.nestStruct = cast(ir.Struct)copyNode(old.nestStruct);
	}
	f.isWeakLink = old.isWeakLink;
	f.vtableIndex = old.vtableIndex;
	f.explicitCallToSuper = old.explicitCallToSuper;
	f.loadDynamic = old.loadDynamic;
	f.isMarkedOverride = old.isMarkedOverride;
	f.isAbstract = old.isAbstract;
	f.isAutoReturn = old.isAutoReturn;
	return f;
}

ir.FunctionParam copy(ir.FunctionParam old, bool copyFn = false)
{
	auto fp = new ir.FunctionParam();
	fp.location = old.location;
	copyDeclaration(fp, old);
	if (copyFn) {
		fp.fn = copy(old.fn);
	}
	fp.index = old.index;
	if (old.assign !is null) {
		fp.assign = copyExp(old.assign);
	}
	fp.name = old.name;
	fp.hasBeenNested = old.hasBeenNested;
	return fp;
}

ir.AsmStatement copy(ir.AsmStatement old)
{
	auto as = new ir.AsmStatement();
	as.location = old.location;
	as.tokens = old.tokens[0..$];
	return as;
}

ir.IfStatement copy(ir.IfStatement old)
{
	auto ifs = new ir.IfStatement();
	ifs.location = old.location;
	ifs.exp = copyExp(old.exp);
	ifs.thenState = copy(old.thenState);
	if (old.elseState !is null) {
		ifs.elseState = copy(old.elseState);
	}
	ifs.autoName = old.autoName;
	return ifs;
}

ir.WhileStatement copy(ir.WhileStatement old)
{
	auto ws = new ir.WhileStatement();
	ws.location = old.location;
	ws.condition = copyExp(old.condition);
	ws.block = copy(old.block);
	return ws;
}

ir.DoStatement copy(ir.DoStatement old)
{
	auto ds = new ir.DoStatement();
	ds.location = old.location;
	ds.block = copy(old.block);
	ds.condition = copyExp(old.condition);
	return ds;
}

ir.ForStatement copy(ir.ForStatement old)
{
	auto fs = new ir.ForStatement();
	fs.location = old.location;
	fs.initVars = new ir.Variable[](old.initVars.length);
	foreach (i, var; old.initVars) {
		fs.initVars[i] = copy(var);
	}
	fs.initExps = new ir.Exp[](old.initExps.length);
	foreach (i, exp; old.initExps) {
		fs.initExps[i] = copyExp(exp);
	}
	if (old.test !is null) {
		fs.test = copyExp(old.test);
	}
	fs.increments = new ir.Exp[](old.increments.length);
	foreach (i, exp; old.increments) {
		fs.increments[i] = copyExp(exp);
	}
	fs.block = copy(old.block);
	return fs;
}

ir.ForeachStatement copy(ir.ForeachStatement old)
{
	auto fs = new ir.ForeachStatement();
	fs.location = old.location;
	fs.reverse = old.reverse;
	fs.itervars = new ir.Variable[](old.itervars.length);
	foreach (i, var; old.itervars) {
		fs.itervars[i] = copy(var);
	}
	if (old.aggregate !is null) {
		fs.aggregate = copyExp(old.aggregate);
	}
	if (old.beginIntegerRange !is null) {
		fs.beginIntegerRange = copyExp(old.beginIntegerRange);
		fs.endIntegerRange = copyExp(old.endIntegerRange);
	}
	fs.block = copy(old.block);
	return fs;
}

ir.LabelStatement copy(ir.LabelStatement old)
{
	auto ls = new ir.LabelStatement();
	ls.location = old.location;
	ls.label = old.label;
	ls.childStatement = new ir.Node[](old.childStatement.length);
	foreach (i, stmt; old.childStatement) {
		ls.childStatement[i] = cast(ir.Statement)copyNode(stmt);
	}
	return ls;
}

ir.ExpStatement copy(ir.ExpStatement old)
{
	auto es = new ir.ExpStatement();
	es.location = old.location;
	es.exp = copyExp(old.exp);
	return es;
}

ir.SwitchStatement copy(ir.SwitchStatement old)
{
	auto ss = new ir.SwitchStatement();
	ss.location = old.location;
	ss.isFinal = old.isFinal;
	ss.condition = copyExp(old.condition);
	ss.cases = new ir.SwitchCase[](old.cases.length);
	foreach (i, c; old.cases) {
		ss.cases[i] = copy(c);
	}
	ss.withs = new ir.Exp[](old.withs.length);
	foreach (i, w; old.withs) {
		ss.withs[i] = copyExp(w);
	}
	return ss;
}

ir.SwitchCase copy(ir.SwitchCase old)
{
	auto sc = new ir.SwitchCase();
	sc.location = old.location;
	sc.firstExp = copyExp(old.firstExp);
	sc.secondExp = copyExp(old.secondExp);
	sc.exps = new ir.Exp[](old.exps.length);
	foreach (i, exp; old.exps) {
		sc.exps[i] = copyExp(exp);
	}
	sc.isDefault = old.isDefault;
	sc.statements = copy(old.statements);
	return sc;
}

ir.ContinueStatement copy(ir.ContinueStatement old)
{
	auto cs = new ir.ContinueStatement();
	cs.location = old.location;
	cs.label = old.label;
	return cs;
}

ir.BreakStatement copy(ir.BreakStatement old)
{
	auto bs = new ir.BreakStatement();
	bs.location = old.location;
	bs.label = old.label;
	return bs;
}

ir.GotoStatement copy(ir.GotoStatement old)
{
	auto gs = new ir.GotoStatement();
	gs.location = old.location;
	gs.label = old.label;
	gs.isDefault = old.isDefault;
	gs.isCase = old.isCase;
	if (old.exp !is null) {
		gs.exp = copyExp(old.exp);
	}
	return gs;
}

ir.WithStatement copy(ir.WithStatement old)
{
	auto ws = new ir.WithStatement();
	ws.location = old.location;
	ws.exp = copyExp(old.exp);
	ws.block = copy(old.block);
	return ws;
}

ir.SynchronizedStatement copy(ir.SynchronizedStatement old)
{
	auto ss = new ir.SynchronizedStatement();
	ss.location = old.location;
	if (old.exp !is null) {
		ss.exp = copyExp(old.exp);
	}
	ss.block = copy(old.block);
	return ss;
}

ir.TryStatement copy(ir.TryStatement old)
{
	auto ts = new ir.TryStatement();
	ts.location = old.location;
	ts.tryBlock = copy(old.tryBlock);
	ts.catchVars = new ir.Variable[](old.catchVars.length);
	foreach (i, var; old.catchVars) {
		ts.catchVars[i] = copy(var);
	}
	ts.catchBlocks = new ir.BlockStatement[](old.catchBlocks.length);
	foreach (i, var; old.catchBlocks) {
		ts.catchBlocks[i] = copy(var);
	}
	if (old.catchAll !is null) {
		ts.catchAll = copy(old.catchAll);
	}
	if (old.finallyBlock !is null) {
		ts.finallyBlock = copy(old.finallyBlock);
	}
	return ts;
}

ir.ThrowStatement copy(ir.ThrowStatement old)
{
	auto ts = new ir.ThrowStatement();
	ts.location = old.location;
	ts.exp = copyExp(old.exp);
	return ts;
}

ir.ScopeStatement copy(ir.ScopeStatement old)
{
	auto ss = new ir.ScopeStatement();
	ss.location = old.location;
	ss.kind = old.kind;
	ss.block = copy(old.block);
	return ss;
}

ir.PragmaStatement copy(ir.PragmaStatement old)
{
	auto ps = new ir.PragmaStatement();
	ps.location = old.location;
	ps.type = old.type;
	ps.arguments = new ir.Exp[](old.arguments.length);
	foreach (i, arg; old.arguments) {
		ps.arguments[i] = copyExp(arg);
	}
	ps.block = copy(old.block);
	return ps;
}

ir.ConditionStatement copy(ir.ConditionStatement old)
{
	auto cs = new ir.ConditionStatement();
	cs.location = old.location;
	cs.condition = copy(old.condition);
	cs.block = copy(old.block);
	cs._else = copy(old._else);
	return cs;
}

ir.MixinStatement copy(ir.MixinStatement old)
{
	auto ms = new ir.MixinStatement();
	ms.location = old.location;
	if (old.stringExp !is null) {
		ms.stringExp = copyExp(old.stringExp);
	}
	if (old.id !is null) {
		ms.id = copy(old.id);
	}
	ms.resolved = copy(old.resolved);
	return ms;
}

ir.AssertStatement copy(ir.AssertStatement old)
{
	auto as = new ir.AssertStatement();
	as.location = old.location;
	as.condition = copyExp(old.condition);
	if (old.message !is null) {
		as.message = copyExp(old.message);
	}
	as.isStatic = old.isStatic;
	return as;
}

ir.Ternary copy(ir.Ternary old)
{
	auto t = new ir.Ternary();
	t.location = old.location;
	t.condition = copyExp(old.condition);
	t.ifTrue = copyExp(old.ifTrue);
	t.ifFalse = copyExp(old.ifFalse);
	return t;
}

ir.AssocArray copy(ir.AssocArray old)
{
	auto aa = new ir.AssocArray();
	aa.location = old.location;
	aa.pairs = new ir.AAPair[](old.pairs.length);
	foreach (i, pair; old.pairs) {
		aa.pairs[i] = copy(pair);
	}
	if (old.type !is null) {
		aa.type = copyType(old.type);
	}
	return aa;
}

ir.AAPair copy(ir.AAPair old)
{
	auto aap = new ir.AAPair();
	aap.location = old.location;
	aap.key = copyExp(old.key);
	aap.value = copyExp(old.value);
	return aap;
}

ir.Assert copy(ir.Assert old)
{
	auto a = new ir.Assert();
	a.location = old.location;
	a.condition = copyExp(old.condition);
	if (old.message !is null) {
		a.message = copyExp(old.message);
	}
	return a;
}

ir.StringImport copy(ir.StringImport old)
{
	auto si = new ir.StringImport();
	si.location = old.location;
	si.filename = copyExp(old.filename);
	return si;
}

ir.IsExp copy(ir.IsExp old)
{
	auto ie = new ir.IsExp();
	ie.location = old.location;
	ie.type = copyType(old.type);
	ie.identifier = old.identifier;
	ie.specialisation = old.specialisation;
	if (old.specType !is null) {
		ie.specType = copyType(old.specType);
	}
	ie.compType = old.compType;
	return ie;
}

ir.TraitsExp copy(ir.TraitsExp old)
{
	auto te = new ir.TraitsExp();
	te.location = old.location;
	te.op = old.op;
	te.target = copy(old.target);
	te.qname = copy(old.qname);
	return te;
}

ir.TemplateInstanceExp copy(ir.TemplateInstanceExp old)
{
	auto tie = new ir.TemplateInstanceExp();
	tie.location = old.location;
	tie.name = old.name;
	tie.types = new ir.TemplateInstanceExp.TypeOrExp[](old.types.length);
	foreach (i, toe; old.types) {
		tie.types[i].exp = toe.exp is null ? null : copyExp(toe.exp);
		tie.types[i].type = toe.type is null ? null : copyType(toe.type);
	}
	return tie;
}

ir.FunctionLiteral copy(ir.FunctionLiteral old)
{
	auto fl = new ir.FunctionLiteral();
	fl.location = old.location;
	fl.isDelegate = old.isDelegate;
	if (old.returnType !is null) {
		fl.returnType = copyType(old.returnType);
	}
	fl.params = new ir.FunctionParameter[](old.params.length);
	foreach (i, param; old.params) {
		fl.params[i] = copy(param);
	}
	fl.block = copy(old.block);
	fl.singleLambdaParam = old.singleLambdaParam;
	if (old.lambdaExp !is null) {
		fl.lambdaExp = copyExp(old.lambdaExp);
	}
	return fl;
}

ir.FunctionParameter copy(ir.FunctionParameter old)
{
	auto fp = new ir.FunctionParameter();
	fp.location = old.location;
	fp.type = copyType(old.type);
	fp.name = old.name;
	return fp;
}

ir.StructLiteral copy(ir.StructLiteral old)
{
	auto sl = new ir.StructLiteral();
	sl.location = old.location;
	sl.exps = new ir.Exp[](old.exps.length);
	foreach (i, exp; old.exps) {
		sl.exps[i] = copyExp(exp);
	}
	sl.type = copyType(old.type);
	return sl;
}

ir.UnionLiteral copy(ir.UnionLiteral old)
{
	auto ul = new ir.UnionLiteral();
	ul.location = old.location;
	ul.exps = new ir.Exp[](old.exps.length);
	foreach (i, exp; old.exps) {
		ul.exps[i] = copyExp(exp);
	}
	ul.type = copyType(old.type);
	return ul;
}

ir.ClassLiteral copy(ir.ClassLiteral old)
{
	auto cl = new ir.ClassLiteral();
	cl.location = old.location;
	cl.exps = new ir.Exp[](old.exps.length);
	foreach (i, exp; old.exps) {
		cl.exps[i] = copyExp(exp);
	}
	cl.type = copyType(old.type);
	cl.useBaseStorage = old.useBaseStorage;
	return cl;
}

ir.EnumDeclaration copy(ir.EnumDeclaration old)
{
	auto ed = new ir.EnumDeclaration();
	ed.location = old.location;
	copyDeclaration(ed, old);
	ed.type = cast(ir.Type)copyNode(old);
	ed.assign = copyExp(old.assign);
	ed.name = old.name;
	if (old.prevEnum !is null) {
		ed.prevEnum = copy(old.prevEnum);
	}
	ed.resolved = old.resolved;
	return ed;
}

ir.FunctionSet copy(ir.FunctionSet old)
{
	auto fs = new ir.FunctionSet();
	fs.location = old.location;
	fs.functions = new ir.Function[](old.functions.length);
	foreach (i, func; old.functions) {
		fs.functions[i] = copy(func);
	}
	if (old.reference !is null) {
		fs.reference = copy(old.reference);
	}
	return fs;
}

ir.FunctionSetType copy(ir.FunctionSetType old)
{
	auto fst = new ir.FunctionSetType();
	fst.location = old.location;
	fst.set = copy(old.set);
	fst.isFromCreateDelegate = old.isFromCreateDelegate;
	return fst;
}

ir.VaArgExp copy(ir.VaArgExp old)
{
	auto vae = new ir.VaArgExp();
	vae.location = old.location;
	vae.arg = copyExp(old.arg);
	vae.type = copyType(old.type);
	return vae;
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
	q.identifiers = new ir.Identifier[](old.identifiers.length);
	foreach (i, oldId; old.identifiers) {
		q.identifiers[i] = copy(oldId);
	}
	return q;
}

/**
 * Helper function that takes care of up
 * casting the return from copyNode.
 */
ir.Type copyType(ir.Type t)
{
	auto node = cast(ir.Type)copyNode(t);
	assert(node !is null);
	return node;
}

/**
 * Helper function that takes care of up
 * casting the return from copyNode.
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

ir.Scope copy(ir.Scope)
{
	// TODO
	return null;
}

void copyAggregate(ir.Aggregate _new, ir.Aggregate old)
{
	_new.name = old.name;
	_new.access = old.access;
	if (old.myScope !is null) {
		_new.myScope = copy(old.myScope);
	}
	if (old.typeInfo !is null) {
		_new.typeInfo = copy(old.typeInfo);
	}
	_new.userAttrs = new ir.Attribute[](old.userAttrs.length);
	foreach (i, attr; old.userAttrs) {
		_new.userAttrs[i] = copy(attr);
	}
	_new.anonymousAggregates = new ir.Aggregate[](old.anonymousAggregates.length);
	foreach (i, aggs; old.anonymousAggregates) {
		_new.anonymousAggregates[i] = cast(ir.Aggregate)copyNode(aggs);
	}
	_new.anonymousVars = new ir.Variable[](old.anonymousVars.length);
	foreach (i, var; old.anonymousVars) {
		_new.anonymousVars[i] = copy(var);
	}
	_new.members = copy(old.members);
	_new.isResolved = old.isResolved;
	_new.isActualized = old.isActualized;
}

void copyDeclaration(ir.Declaration _new, ir.Declaration old)
{
	_new.userAttrs = new ir.Attribute[](old.userAttrs.length);
	foreach (i, attr; old.userAttrs) {
		_new.userAttrs[i] = copy(attr);
	}
	_new.oldname = old.oldname;
}

/**
 * Copies a node and all its children nodes.
 */
ir.Node copyNode(ir.Node n)
{
	final switch (n.nodeType) with (ir.NodeType) {
	case Invalid:
		auto msg = format("cannot copy '%s'", ir.nodeToString(n));
		throw panic(n.location, msg);
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
	case Enum:
		auto e = cast(ir.Enum)n;
		return copy(e);
	case StatementExp:
		auto se = cast(ir.StatementExp)n;
		return copy(se);
	case PrimitiveType:
		auto pt = cast(ir.PrimitiveType)n;
		return copy(pt);
	case TypeReference:
		auto tr = cast(ir.TypeReference)n;
		return copy(tr);
	case PointerType:
		auto pt = cast(ir.PointerType)n;
		return copy(pt);
	case NullType:
		auto nt = cast(ir.NullType)n;
		return copy(nt);
	case ArrayType:
		auto at = cast(ir.ArrayType)n;
		return copy(at);
	case StaticArrayType:
		auto sat = cast(ir.StaticArrayType)n;
		return copy(sat);
	case AAType:
		auto aa = cast(ir.AAType)n;
		return copy(aa);
	case AAPair:
		auto aap = cast(ir.AAPair)n;
		return aap;
	case FunctionType:
		auto ft = cast(ir.FunctionType)n;
		return ft;
	case DelegateType:
		auto dt = cast(ir.DelegateType)n;
		return copy(dt);
	case StorageType:
		auto st = cast(ir.StorageType)n;
		return copy(st);
	case TypeOf:
		auto to = cast(ir.TypeOf)n;
		return copy(to);
	case Struct:
		auto s = cast(ir.Struct)n;
		return copy(s);
	case Class:
		auto c = cast(ir.Class)n;
		return copy(c);
	case Interface:
		auto i = cast(ir._Interface)n;
		return copy(i);
	case QualifiedName:
		auto qname = cast(ir.QualifiedName)n;
		return copy(qname);
	case Identifier:
		auto i = cast(ir.Identifier)n;
		return copy(i);
	case Module:
		auto m = cast(ir.Module)n;
		return copy(m);
	case TopLevelBlock:
		auto tlb = cast(ir.TopLevelBlock)n;
		return copy(tlb);
	case Import:
		auto i = cast(ir.Import)n;
		return copy(i);
	case Unittest:
		auto u = cast(ir.Unittest)n;
		return copy(u);
	case Union:
		auto u = cast(ir.Union)n;
		return copy(u);
	case Attribute:
		auto a = cast(ir.Attribute)n;
		return copy(a);
	case StaticAssert:
		auto sa = cast(ir.StaticAssert)n;
		return copy(sa);
	case MixinTemplate:
		auto mt = cast(ir.MixinTemplate)n;
		return copy(mt);
	case MixinFunction:
		auto mf = cast(ir.MixinFunction)n;
		return copy(mf);
	case UserAttribute:
		auto ua = cast(ir.UserAttribute)n;
		return copy(ua);
	case Condition:
		auto c = cast(ir.Condition)n;
		return copy(c);
	case ConditionTopLevel:
		auto ctl = cast(ir.ConditionTopLevel)n;
		return copy(ctl);
	case Variable:
		auto v = cast(ir.Variable)n;
		return copy(v);
	case Alias:
		auto a = cast(ir.Alias)n;
		return copy(a);
	case Function:
		auto f = cast(ir.Function)n;
		return copy(f);
	case FunctionParam:
		auto fp = cast(ir.FunctionParam)n;
		return copy(fp);
	case AsmStatement:
		auto as = cast(ir.AsmStatement)n;
		return copy(as);
	case IfStatement:
		auto ifs = cast(ir.IfStatement)n;
		return copy(ifs);
	case WhileStatement:
		auto ws = cast(ir.WhileStatement)n;
		return copy(ws);
	case DoStatement:
		auto ds = cast(ir.DoStatement)n;
		return copy(ds);
	case ForStatement:
		auto fs = cast(ir.ForStatement)n;
		return fs;
	case ForeachStatement:
		auto fes = cast(ir.ForeachStatement)n;
		return copy(fes);
	case LabelStatement:
		auto ls = cast(ir.LabelStatement)n;
		return copy(ls);
	case ExpStatement:
		auto es = cast(ir.ExpStatement)n;
		return copy(es);
	case SwitchStatement:
		auto ss = cast(ir.SwitchStatement)n;
		return copy(ss);
	case SwitchCase:
		auto sc = cast(ir.SwitchCase)n;
		return copy(sc);
	case ContinueStatement:
		auto cs = cast(ir.ContinueStatement)n;
		return copy(cs);
	case BreakStatement:
		auto bs = cast(ir.BreakStatement)n;
		return copy(bs);
	case GotoStatement:
		auto gs = cast(ir.GotoStatement)n;
		return copy(gs);
	case WithStatement:
		auto ws = cast(ir.WithStatement)n;
		return copy(ws);
	case SynchronizedStatement:
		auto ss = cast(ir.SynchronizedStatement)n;
		return copy(ss);
	case TryStatement:
		auto ts = cast(ir.TryStatement)n;
		return copy(ts);
	case ThrowStatement:
		auto ts = cast(ir.ThrowStatement)n;
		return copy(ts);
	case ScopeStatement:
		auto ss = cast(ir.ScopeStatement)n;
		return copy(ss);
	case PragmaStatement:
		auto ps = cast(ir.PragmaStatement)n;
		return copy(ps);
	case ConditionStatement:
		auto cs = cast(ir.ConditionStatement)n;
		return copy(cs);
	case MixinStatement:
		auto ms = cast(ir.MixinStatement)n;
		return copy(ms);
	case AssertStatement:
		auto as = cast(ir.AssertStatement)n;
		return copy(as);
	case Comma:
		goto case Invalid;
	case Ternary:
		auto t = cast(ir.Ternary)n;
		return copy(t);
	case AssocArray:
		auto aa = cast(ir.AssocArray)n;
		return copy(aa);
	case Assert:
		auto a = cast(ir.Assert)n;
		return copy(a);
	case StringImport:
		auto si = cast(ir.StringImport)n;
		return copy(si);
	case IsExp:
		auto ie = cast(ir.IsExp)n;
		return copy(ie);
	case TraitsExp:
		auto te = cast(ir.TraitsExp)n;
		return copy(te);
	case TemplateInstanceExp:
		auto tie = cast(ir.TemplateInstanceExp)n;
		return copy(tie);
	case FunctionLiteral:
		auto fl = cast(ir.FunctionLiteral)n;
		return copy(fl);
	case StructLiteral:
		auto sl = cast(ir.StructLiteral)n;
		return copy(sl);
	case UnionLiteral:
		auto ul = cast(ir.UnionLiteral)n;
		return copy(ul);
	case ClassLiteral:
		auto cl = cast(ir.ClassLiteral)n;
		return copy(cl);
	case EnumDeclaration:
		auto ed = cast(ir.EnumDeclaration)n;
		return copy(ed);
	case FunctionSet:
		auto fs = cast(ir.FunctionSet)n;
		return copy(fs);
	case FunctionSetType:
		auto fst = cast(ir.FunctionSetType)n;
		return copy(fst);
	case VaArgExp:
		auto vae = cast(ir.VaArgExp)n;
		return copy(vae);
	case BuiltinExp:
		goto case Invalid;
	}
	version (Volt) assert(false); // ???
}
