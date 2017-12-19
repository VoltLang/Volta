/*#D*/
// Copyright © 2012-2017, Bernard Helyer.
// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Module that deals with gatherering symbols into scopes.
 *
 * Holds the @ref Gatherer class and lots of helper functions
 *
 * @ingroup passPost
 */
module volta.postparse.gatherer;

import watt.text.format : format;

import ir = volta.ir;
import volta.util.util;
import volta.util.copy;

import volta.errors;
import volta.interfaces;
import volta.ir.location;
import volta.visitor.visitor;


//! Used to keep track of which level a symbol was found.
enum Where
{
	Module,
	TopLevel,
	Function,
}

ir.Store findShadowed(ir.Scope _scope, ref in Location loc, string name, bool warningsEnabled)
{
	auto store = _scope.getStore(name);

	if (store !is null &&
		(_scope.node.nodeType == ir.NodeType.Class ||
		_scope.node.nodeType == ir.NodeType.Struct ||
		_scope.node.nodeType == ir.NodeType.Union)) {
		warningShadowsField(/*#ref*/loc, /*#ref*/store.node.loc, name, warningsEnabled);
		return null;
	}

	// BlockStatements attached directly to a function have their .node set to that function.
	if ((_scope.node.nodeType != ir.NodeType.Function &&
	    _scope.node.nodeType != ir.NodeType.BlockStatement) ||
		(_scope.node.nodeType == ir.NodeType.Function &&
		_scope.parent.node.nodeType == ir.NodeType.BlockStatement)) {
		return null;
	}

	// We don't use lookupOnlyThisScope because it will try and resolve it prematurely.
	if (store !is null) {
		return store;
	}

	if (_scope.parent !is null) {
		return findShadowed(_scope.parent, /*#ref*/loc, name, warningsEnabled);
	} else {
		return null;
	}
}

bool isValidAccess(ir.Access access)
{
	switch (access) with (ir.Access) {
	case Private, Public, Protected:
		return true;
	default:
		return false;
	}
}


/*
 *
 * Add named declarations to scopes.
 *
 */

void gather(ir.Scope current, ir.EnumDeclaration e, Where where, ErrorSink errSink)
{
	// @TODO passert(e.access.isValidAccess());
	ir.Status status;
	current.addEnumDeclaration(e, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, e, "enum declaration redefinition");
		return;
	}
}

void gather(ir.Scope current, ir.Alias a, Where where, ErrorSink errSink)
{
	passert(errSink, a, a.access.isValidAccess());
	passert(errSink, a, a.lookScope is null);
	passert(errSink, a, a.lookModule is null);

	a.lookScope = current;
	ir.Status status;
	a.store = current.addAlias(a, a.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, a, "multiple definition");
		return;
	}
}

/*!
 * If name is reserved in current, generate an error pointing at n's location.
 */
void checkInvalid(ir.Scope current, ir.Node n, string name, ErrorSink errSink)
{
	auto store = current.getStore(name);
	if (store !is null && store.kind == ir.Store.Kind.Reserved) {
		errorMsg(errSink, store.node, format("'%s' is a reserved name in this scope.", name));
		return;
	}
}

void checkTemplateRedefinition(ir.Scope current, string name, ErrorSink errSink)
{
	auto store = current.getStore(name);
	if (store !is null && store.kind == ir.Store.Kind.Type) {
		errorMsg(errSink, store.node, format("'%s' is already defined in this scope.", name));
		return;
	}
}

void gather(ir.Scope current, ir.Variable v, Where where, ir.Function[] functionStack, bool warningsEnabled, ErrorSink errSink)
{
	passert(errSink, v, v.access.isValidAccess());

	// TODO Move to semantic.
	auto shadowStore = findShadowed(current, /*#ref*/v.loc, v.name, warningsEnabled);
	if (shadowStore !is null) {
		errorMsg(errSink, v, shadowsDeclarationMsg(v));
		return;
	}

	checkInvalid(current, v, v.name, errSink);
	auto store = current.getStore(v.name);
	if (store !is null) {
		errorMsg(errSink, v, format("'%s' is in use @ %s.", v.name, store.node.loc.toString()));
		return;
	}
	ir.Status status;
	current.addValue(v, v.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, v, "value redefinition");
		return;
	}

	if (v.storage != ir.Variable.Storage.Invalid) {
		return;
	}

	if (where == Where.Module) {
		errorExpected(errSink, v, "global or local");
		return;
	}

	v.storage = where == Where.Function ?
		ir.Variable.Storage.Function :
		ir.Variable.Storage.Field;
}

void gather(ir.Scope current, ir.Function func, Where where, ErrorSink errSink)
{
	passert(errSink, func, func.access.isValidAccess());

	if (func.name !is null) {
		checkInvalid(current, func, func.name, errSink);
		ir.Status status;
		current.addFunction(func, func.name, /*#out*/status);
		if (status != ir.Status.Success) {
			panic(errSink, func, "function redefinition");
			return;
		}
	}

	if (func.kind == ir.Function.Kind.Invalid) {
		if (where == Where.TopLevel) {
			func.kind = ir.Function.Kind.Member;
		} else {
			if (func.isAbstract) {
				errorMsg(errSink, func, abstractHasToBeMemberMsg(func));
				return;
			}
			func.kind = ir.Function.Kind.Function;
		}
	}
}

void gather(ir.Scope current, ir.Struct s, Where where, ErrorSink errSink)
{
	passert(errSink, s, s.access.isValidAccess());
	passert(errSink, s, s.myScope !is null);

	checkInvalid(current, s, s.name, errSink);
	checkTemplateRedefinition(current, s.name, errSink);
	ir.Status status;
	current.addType(s, s.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, s, "gather redefinition");
		return;
	}
}

void gather(ir.Scope current, ir.Union u, Where where, ErrorSink errSink)
{
	passert(errSink, u, u.access.isValidAccess());
	passert(errSink, u, u.myScope !is null);

	checkInvalid(current, u, u.name, errSink);
	checkTemplateRedefinition(current, u.name, errSink);
	ir.Status status;
	current.addType(u, u.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, u, "gather redefinition");
		return;
	}
}

void gather(ir.Scope current, ir.Class c, Where where, ErrorSink errSink)
{
	passert(errSink, c, c.access.isValidAccess());
	passert(errSink, c, c.myScope !is null);

	checkInvalid(current, c, c.name, errSink);
	checkTemplateRedefinition(current, c.name, errSink);
	ir.Status status;
	current.addType(c, c.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, c, "gather redefinition");
		return;
	}
}

void gather(ir.Scope current, ir.Enum e, Where where, ErrorSink errSink)
{
	passert(errSink, e, e.access.isValidAccess());
	passert(errSink, e, e.myScope !is null);

	checkInvalid(current, e, e.name, errSink);
	checkTemplateRedefinition(current, e.name, errSink);
	ir.Status status;
	current.addType(e, e.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, e, "gather redefinition");
		return;
	}
}

void gather(ir.Scope current, ir._Interface i, Where where, ErrorSink errSink)
{
	passert(errSink, i, i.access.isValidAccess());
	passert(errSink, i, i.myScope !is null);

	checkInvalid(current, i, i.name, errSink);
	checkTemplateRedefinition(current, i.name, errSink);
	ir.Status status;
	current.addType(i, i.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, i, "gather redefinition");
		return;
	}
}

void gather(ir.Scope current, ir.MixinFunction mf, Where where, ErrorSink errSink)
{
	// @TODO passert(mf.access.isValidAccess());

	checkInvalid(current, mf, mf.name, errSink);
	ir.Status status;
	current.addTemplate(mf, mf.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, mf, "template redefinition");
		return;
	}
}

void gather(ir.Scope current, ir.MixinTemplate mt, Where where, ErrorSink errSink)
{
	// @TODO passert(mt.access.isValidAccess());

	checkInvalid(current, mt, mt.name, errSink);
	ir.Status status;
	current.addTemplate(mt, mt.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, mt, "template redefinition");
		return;
	}
}

void gather(ir.Scope current, ir.TemplateDefinition td, Where where, ErrorSink errSink)
{
	checkInvalid(current, td, td.name, errSink);
	checkTemplateRedefinition(current, td.name, errSink);
	ir.Status status;
	current.addTemplate(td, td.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, td, "template redefinition");
		return;
	}
}


/*
 *
 * Adding scopes to nodes.
 *
 */

void addScope(ir.Module m)
{
	if (m.myScope !is null) {
		return;
	}

	string name = m.name.identifiers[$-1].value;
	m.myScope = new ir.Scope(m, name);
}

void addScope(ir.Scope current, ir.Function func, ir.Type thisType, ir.Function[] functionStack, ErrorSink errSink)
{
	int nestedDepth = current.nestedDepth;
	if (func.kind == ir.Function.Kind.Nested ||
	    func.kind == ir.Function.Kind.GlobalNested) {
		nestedDepth++;
	}
	func.myScope = new ir.Scope(current, func, func.name, nestedDepth);

	if (func._body !is null) {
		foreach (var; func.params) {
			if (var.name !is null) {
				ir.Status status;
				func.myScope.addValue(var, var.name, /*#out*/status);
				if (status != ir.Status.Success) {
					panic(errSink, func, "value redefinition");
					return;
				}
			}
		}
	}

	if (thisType is null || func.kind == ir.Function.Kind.Function) {
		passert(errSink, func,
		       func.kind != ir.Function.Kind.Member &&
		       func.kind != ir.Function.Kind.Destructor &&
		       func.kind != ir.Function.Kind.Constructor);
		return;
	}

	auto tr = buildTypeReference(/*#ref*/thisType.loc, thisType,  "__this");

	auto thisVar = new ir.Variable();
	thisVar.loc = func.loc;
	thisVar.type = tr;
	thisVar.name = "this";
	thisVar.storage = ir.Variable.Storage.Function;
	// For classes this needs to be set.
	thisVar.useBaseStorage = cast(ir.Class)thisType !is null;

	// Don't add it, it will get added by the variable code.
	func.thisHiddenParameter = thisVar;
	func.type.hiddenParameter = true;
}

void addScope(ir.Scope current, ir.BlockStatement bs)
{
	if (bs.myScope !is null) {
		return;
	}
	bs.myScope = new ir.Scope(current, bs, "block", current.nestedDepth);
}

void addScope(ir.Scope current, ir.Struct s, ErrorSink errSink)
{
	auto agg = cast(ir.Aggregate) current.node;
	if (s.name is null && agg is null) {
		errorMsg(errSink, s, anonymousAggregateAtTopLevelMsg());
		return;
	}
	if (s.name is null) {
		agg.anonymousAggregates ~= s;
		auto name = format("%s_anonymous", agg.anonymousAggregates.length);
		s.name = format("%s_anonymous_t", agg.anonymousAggregates.length);
		agg.anonymousVars ~= buildVariableSmart(/*#ref*/s.loc, s, ir.Variable.Storage.Field, name);
		agg.members.nodes ~= agg.anonymousVars[$-1];
	}
	passert(errSink, s, s.myScope is null);
	s.myScope = new ir.Scope(current, s, s.name, current.nestedDepth);
}

void addScope(ir.Scope current, ir.Union u, ErrorSink errSink)
{
	auto agg = cast(ir.Aggregate) current.node;
	if (u.name is null && agg is null) {
		errorMsg(errSink, u, anonymousAggregateAtTopLevelMsg());
		return;
	}
	if (u.name is null) {
		agg.anonymousAggregates ~= u;
		auto name = format("%s_anonymous", agg.anonymousAggregates.length);
		u.name = format("%s_anonymous_t", agg.anonymousAggregates.length);
		agg.anonymousVars ~= buildVariableSmart(/*#ref*/u.loc, u, ir.Variable.Storage.Field, name);
		agg.members.nodes ~= agg.anonymousVars[$-1];
	}	
	passert(errSink, u, u.myScope is null);
	u.myScope = new ir.Scope(current, u, u.name, current.nestedDepth);
}

void addScope(ir.Scope current, ir.Enum e, ErrorSink errSink)
{
	passert(errSink, e, e.myScope is null);
	e.myScope = new ir.Scope(current, e, e.name, current.nestedDepth);
}

void addScope(ir.Scope current, ir.Class c, Where where, ErrorSink errSink)
{
	if (c.name is null) {
		panic(errSink, c, "anonymous classes not supported");
		return;
	}

	passert(errSink, c, c.myScope is null);
	c.myScope = new ir.Scope(current, c, c.name, current.nestedDepth);
}

void addScope(ir.Scope current, ir._Interface i, ErrorSink errSink)
{
	if (i.name is null) {
		panic(errSink, i, "anonymous interfaces not supported");
		return;
	}

	passert(errSink, i, i.myScope is null);
	i.myScope = new ir.Scope(current, i, i.name, current.nestedDepth);
}

/*!
 * Populate the scopes with Variables, Aliases, Functions, and Types.
 * Adds Scopes where needed as well.
 *
 * @ingroup passes passLang passPost
 */
class Gatherer : NullVisitor, Pass
{
protected:
	Where[] mWhere;
	ir.Scope[] mScope;
	ir.Type[] mThis;
	ir.Function[] mFunctionStack;
	ir.Module mModule;
	bool mWarningsEnabled;
	ErrorSink mErrSink;

public:
	this(bool warningsEnabled, ErrorSink errSink)
	{
		mWarningsEnabled = warningsEnabled;
		mErrSink = errSink;
	}


	/*
	 *
	 * Pass functions.
	 *
	 */

	override void transform(ir.Module m)
	{
		if (m.gathered) {
			return;
		}

		mModule = m;
		accept(m, this);
		m.gathered = true;

		passert(mErrSink, m, mWhere.length == 0);
	}

	void transform(ir.Scope current, ir.BlockStatement bs)
	{
		passert(mErrSink, bs, mWhere.length == 0);
		push(current);
		accept(bs, this);
		pop();
		passert(mErrSink, bs, mWhere.length == 0);
	}

	override void close()
	{

	}


	/*
	 *
	 * Helpers.
	 *
	 */

	void push(ir.Scope s, ir.Type thisType = null)
	{
		mWhere ~= thisType is null ?
			Where.Function :
			Where.TopLevel;
		mScope ~= s;

		if (thisType !is null) {
			mThis ~= thisType;
		}
	}

	void pop(ir.Type thisType = null)
	{
		mScope = mScope[0 .. $-1];
		mWhere = mWhere[0 .. $-1];

		if (thisType !is null) {
			passert(mErrSink, thisType, thisType is mThis[$-1]);
			mThis = mThis[0 .. $-1];
		}
	}

	void push(ir.Function func)
	{
		push(func.myScope);
		mFunctionStack ~= func;
	}

	void pop(ir.Function func)
	{
		pop();
		passert(mErrSink, func, func is mFunctionStack[$-1]);
		mFunctionStack = mFunctionStack[0 .. $-1];
	}

	@property Where where()
	{
		return mWhere[$-1];
	}

	@property ir.Scope current()
	{
		return mScope[$-1];
	}

	@property ir.Type thisType()
	{
		return mThis[$-1];
	}


	/*
	 *
	 * Visitor functions.
	 *
	 */

	override Status enter(ir.Module m)
	{
		addScope(m);

		push(m.myScope);

		// The code will think this is a function otherwise.
		passert(mErrSink, m, mWhere.length == 1);
		mWhere[0] = Where.Module;

		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		gather(current, a, where, mErrSink);
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		gather(current, v, where, mFunctionStack, mWarningsEnabled, mErrSink);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		addScope(current, c, where, mErrSink);
		gather(current, c, where, mErrSink);
		push(c.myScope, c);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		addScope(current, i, mErrSink);
		gather(current, i, where, mErrSink);
		push(i.myScope, i);
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		if (s.myScope is null) {
			addScope(current, s, mErrSink);
			gather(current, s, where, mErrSink);
		}
		push(s.myScope, s);
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		addScope(current, u, mErrSink);
		gather(current, u, where, mErrSink);
		push(u.myScope, u);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		addScope(current, e, mErrSink);
		gather(current, e, where, mErrSink);
		push(e.myScope, e);
		return Continue;
	}

	override Status enter(ir.Function func)
	{
		ir.Type thisType;
		if (where == Where.TopLevel ) {
			thisType = this.thisType;
		} else if (where == Where.Function && func.kind != ir.Function.Kind.GlobalNested) {
			func.kind = ir.Function.Kind.Nested;
		}

		gather(current, func, where, mErrSink);
		addScope(current, func, thisType, mFunctionStack, mErrSink);
		push(func);

		// I don't think this is the right place for this.
		if (func.isAbstract && func._body !is null) {
			errorMsg(mErrSink, func, abstractBodyNotEmptyMsg(func));
			return Continue;
		}
		return Continue;
	}

	override Status enter(ir.ForeachStatement fes)
	{
		enter(fes.block);
		foreach (var; fes.itervars) {
			gather(current, var, where, mFunctionStack, mWarningsEnabled, mErrSink);
		}
		if (fes.aggregate !is null) acceptExp(/*#ref*/fes.aggregate, this);
		if (fes.beginIntegerRange !is null) {
			passert(mErrSink, fes, fes.endIntegerRange !is null);
			acceptExp(/*#ref*/fes.beginIntegerRange, this);
			acceptExp(/*#ref*/fes.endIntegerRange, this);
		}
		foreach (node; fes.block.statements) {
			accept(node, this);
		}
		leave(fes.block);
		return ContinueParent;
	}

	override Status enter(ir.ForStatement fs)
	{
		enter(fs.block);
		foreach (var; fs.initVars) {
			gather(current, var, where, mFunctionStack, mWarningsEnabled, mErrSink);
		}
		if (fs.test !is null) {
			acceptExp(/*#ref*/fs.test, this);
		}
		foreach (ref inc; fs.increments) {
			acceptExp(/*#ref*/inc, this);
		}
		foreach (node; fs.block.statements) {
			accept(node, this);
		}
		leave(fs.block);
		return ContinueParent;
	}

	override Status enter(ir.BlockStatement bs)
	{
		addScope(current, bs);
		push(bs.myScope);
		// TODO: unittest stuff triggers this
		if (mFunctionStack.length == 0) {
			panic(mErrSink, bs, "block statement outside of function");
			return Continue;
		}
		return Continue;
	}

	override Status enter(ir.MixinFunction mf)
	{
		gather(current, mf, where, mErrSink);
		return Continue;
	}

	override Status enter(ir.MixinTemplate mt)
	{
		gather(current, mt, where, mErrSink);
		return Continue;
	}

	override Status enter(ir.EnumDeclaration e)
	{
		gather(current, e, where, mErrSink);
		return Continue;
	}

	override Status visit(ir.TemplateDefinition td)
	{
		gather(current, td, where, mErrSink);
		return Continue;
	}

	override Status leave(ir.Module m) { pop(); return Continue; }
	override Status leave(ir.Class c) { pop(c); return Continue; }
	override Status leave(ir.Struct s) { pop(s); return Continue; }
	override Status leave(ir.Union u) { pop(u); return Continue; }
	override Status leave(ir.Enum e) { pop(e); return Continue; }
	override Status leave(ir.Function func) { pop(func); return Continue; }
	override Status leave(ir.BlockStatement bs) { pop(); return Continue; }
	override Status leave(ir._Interface i) { pop(i); return Continue; }
}
