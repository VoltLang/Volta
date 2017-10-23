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
module volt.postparse.gatherer;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;


//! Used to keep track of which level a symbol was found.
enum Where
{
	Module,
	TopLevel,
	Function,
}

ir.Store findShadowed(ir.Scope _scope, Location loc, string name, bool warningsEnabled)
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

void gather(ir.Scope current, ir.EnumDeclaration e, Where where)
{
	// @TODO assert(e.access.isValidAccess());
	current.addEnumDeclaration(e);
}

void gather(ir.Scope current, ir.Alias a, Where where)
{
	assert(a.access.isValidAccess());
	assert(a.lookScope is null);
	assert(a.lookModule is null);

	a.lookScope = current;
	a.store = current.addAlias(a, a.name);
}

/*!
 * If name is reserved in current, throw an error pointing at n's location.
 */
void checkInvalid(ir.Scope current, ir.Node n, string name)
{
	auto store = current.getStore(name);
	if (store !is null && store.kind == ir.Store.Kind.Reserved) {
		throw makeError(store.node, format("'%s' is a reserved name in this scope.", name));
	}
}

void checkTemplateRedefinition(ir.Scope current, string name)
{
	auto store = current.getStore(name);
	if (store !is null && store.kind == ir.Store.Kind.Type) {
		throw makeError(store.node, format("'%s' is already defined in this scope.",
		name));
	}
}

void gather(ir.Scope current, ir.Variable v, Where where, ir.Function[] functionStack, bool warningsEnabled)
{
	assert(v.access.isValidAccess());

	// TODO Move to semantic.
	auto shadowStore = findShadowed(current, /*#ref*/v.loc, v.name, warningsEnabled);
	if (shadowStore !is null) {
		throw makeShadowsDeclaration(v, shadowStore.node);
	}

	checkInvalid(current, v, v.name);
	auto store = current.getStore(v.name);
	if (store !is null) {
		throw makeError(/*#ref*/v.loc, format("'%s' is in use @ %s.", v.name, store.node.loc.toString()));
	}
	current.addValue(v, v.name);

	if (v.storage != ir.Variable.Storage.Invalid) {
		return;
	}

	if (where == Where.Module) {
		throw makeExpected(v, "global or local");
	}

	v.storage = where == Where.Function ?
		ir.Variable.Storage.Function :
		ir.Variable.Storage.Field;
}

void gather(ir.Scope current, ir.Function func, Where where)
{
	assert(func.access.isValidAccess());

	if (func.name !is null) {
		checkInvalid(current, func, func.name);
		current.addFunction(func, func.name);
	}

	if (func.kind == ir.Function.Kind.Invalid) {
		if (where == Where.TopLevel) {
			func.kind = ir.Function.Kind.Member;
		} else {
			if (func.isAbstract) {
				throw makeAbstractHasToBeMember(func, func);
			}
			func.kind = ir.Function.Kind.Function;
		}
	}
}

void gather(ir.Scope current, ir.Struct s, Where where)
{
	assert(s.access.isValidAccess());
	assert(s.myScope !is null);

	checkInvalid(current, s, s.name);
	checkTemplateRedefinition(current, s.name);
	current.addType(s, s.name);
}

void gather(ir.Scope current, ir.Union u, Where where)
{
	assert(u.access.isValidAccess());
	assert(u.myScope !is null);

	checkInvalid(current, u, u.name);
	checkTemplateRedefinition(current, u.name);
	current.addType(u, u.name);
}

void gather(ir.Scope current, ir.Class c, Where where)
{
	assert(c.access.isValidAccess());
	assert(c.myScope !is null);

	checkInvalid(current, c, c.name);
	checkTemplateRedefinition(current, c.name);
	current.addType(c, c.name);
}

void gather(ir.Scope current, ir.Enum e, Where where)
{
	assert(e.access.isValidAccess());
	assert(e.myScope !is null);

	checkInvalid(current, e, e.name);
	checkTemplateRedefinition(current, e.name);
	current.addType(e, e.name);
}

void gather(ir.Scope current, ir._Interface i, Where where)
{
	assert(i.access.isValidAccess());
	assert(i.myScope !is null);

	checkInvalid(current, i, i.name);
	checkTemplateRedefinition(current, i.name);
	current.addType(i, i.name);
}

void gather(ir.Scope current, ir.MixinFunction mf, Where where)
{
	// @TODO assert(mf.access.isValidAccess());

	checkInvalid(current, mf, mf.name);
	current.addTemplate(mf, mf.name);
}

void gather(ir.Scope current, ir.MixinTemplate mt, Where where)
{
	// @TODO assert(mt.access.isValidAccess());

	checkInvalid(current, mt, mt.name);
	current.addTemplate(mt, mt.name);
}

void gather(ir.Scope current, ir.TemplateDefinition td, Where where)
{
	checkInvalid(current, td, td.name);
	checkTemplateRedefinition(current, td.name);
	current.addTemplate(td, td.name);
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

void addScope(ir.Scope current, ir.Function func, ir.Type thisType, ir.Function[] functionStack)
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
				func.myScope.addValue(var, var.name);
			}
		}
	}

	if (thisType is null || func.kind == ir.Function.Kind.Function) {
		assert(func.kind != ir.Function.Kind.Member &&
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

void addScope(ir.Scope current, ir.Struct s)
{
	auto agg = cast(ir.Aggregate) current.node;
	if (s.name is null && agg is null) {
		throw makeAnonymousAggregateAtTopLevel(s);
	}
	if (s.name is null) {
		agg.anonymousAggregates ~= s;
		auto name = format("%s_anonymous", agg.anonymousAggregates.length);
		s.name = format("%s_anonymous_t", agg.anonymousAggregates.length);
		agg.anonymousVars ~= buildVariableSmart(/*#ref*/s.loc, s, ir.Variable.Storage.Field, name);
		agg.members.nodes ~= agg.anonymousVars[$-1];
	}
	assert(s.myScope is null);
	s.myScope = new ir.Scope(current, s, s.name, current.nestedDepth);
}

void addScope(ir.Scope current, ir.Union u)
{
	auto agg = cast(ir.Aggregate) current.node;
	if (u.name is null && agg is null) {
		throw makeAnonymousAggregateAtTopLevel(u);
	}
	if (u.name is null) {
		agg.anonymousAggregates ~= u;
		auto name = format("%s_anonymous", agg.anonymousAggregates.length);
		u.name = format("%s_anonymous_t", agg.anonymousAggregates.length);
		agg.anonymousVars ~= buildVariableSmart(/*#ref*/u.loc, u, ir.Variable.Storage.Field, name);
		agg.members.nodes ~= agg.anonymousVars[$-1];
	}	
	assert(u.myScope is null);
	u.myScope = new ir.Scope(current, u, u.name, current.nestedDepth);
}

void addScope(ir.Scope current, ir.Enum e)
{
	assert(e.myScope is null);
	e.myScope = new ir.Scope(current, e, e.name, current.nestedDepth);
}

void addScope(ir.Scope current, ir.Class c, Where where)
{
	if (c.name is null) {
		throw panic(c, "anonymous classes not supported");
	}

	assert(c.myScope is null);
	c.myScope = new ir.Scope(current, c, c.name, current.nestedDepth);
}

void addScope(ir.Scope current, ir._Interface i)
{
	if (i.name is null) {
		throw panic(i, "anonymous interfaces not supported");
	}

	assert(i.myScope is null);
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

public:
	this(bool warningsEnabled)
	{
		mWarningsEnabled = warningsEnabled;
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

		assert(mWhere.length == 0);
	}

	void transform(ir.Scope current, ir.BlockStatement bs)
	{
		assert(mWhere.length == 0);
		push(current);
		accept(bs, this);
		pop();
		assert(mWhere.length == 0);
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
			assert(thisType is mThis[$-1]);
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
		assert(func is mFunctionStack[$-1]);
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
		assert(mWhere.length == 1);
		mWhere[0] = Where.Module;

		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		gather(current, a, where);
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		gather(current, v, where, mFunctionStack, mWarningsEnabled);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		addScope(current, c, where);
		gather(current, c, where);
		push(c.myScope, c);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		addScope(current, i);
		gather(current, i, where);
		push(i.myScope, i);
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		if (s.myScope is null) {
			addScope(current, s);
			gather(current, s, where);
		}
		push(s.myScope, s);
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		addScope(current, u);
		gather(current, u, where);
		push(u.myScope, u);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		addScope(current, e);
		gather(current, e, where);
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

		gather(current, func, where);
		addScope(current, func, thisType, mFunctionStack);
		push(func);

		// I don't think this is the right place for this.
		if (func.isAbstract && func._body !is null) {
			throw makeAbstractBodyNotEmpty(func, func);
		}
		return Continue;
	}

	override Status enter(ir.ForeachStatement fes)
	{
		enter(fes.block);
		foreach (var; fes.itervars) {
			gather(current, var, where, mFunctionStack, mWarningsEnabled);
		}
		if (fes.aggregate !is null) acceptExp(/*#ref*/fes.aggregate, this);
		if (fes.beginIntegerRange !is null) {
			panicAssert(fes, fes.endIntegerRange !is null);
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
			gather(current, var, where, mFunctionStack, mWarningsEnabled);
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
			throw panic(/*#ref*/bs.loc, "block statement outside of function");
		}
		return Continue;
	}

	override Status enter(ir.MixinFunction mf)
	{
		gather(current, mf, where);
		return Continue;
	}

	override Status enter(ir.MixinTemplate mt)
	{
		gather(current, mt, where);
		return Continue;
	}

	override Status enter(ir.EnumDeclaration e)
	{
		gather(current, e, where);
		return Continue;
	}

	override Status visit(ir.TemplateDefinition td)
	{
		gather(current, td, where);
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
