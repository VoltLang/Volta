// Copyright © 2012, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.postparse.gatherer;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;


enum Where
{
	Module,
	TopLevel,
	Function,
}

ir.Store findShadowed(ir.Scope _scope, Location loc, string name)
{
	// BlockStatements attached directly to a function have their .node set to that function.
	if (_scope.node.nodeType != ir.NodeType.Function &&
	    _scope.node.nodeType != ir.NodeType.BlockStatement) {
		return null;
	}

	// We don't use lookupOnlyThisScope because it will try and resolve it prematurely.
	auto store = _scope.getStore(name);
	if (store !is null) {
		return store;
	}

	if (_scope.parent !is null) {
		if (_scope.node.nodeType == ir.NodeType.Function &&
		    _scope.parent.node.nodeType == ir.NodeType.Function) {
			return null;
		}
		return findShadowed(_scope.parent, loc, name);
	} else {
		return null;
	}
	version (Volt) assert(false); // If
}

bool isValidAccess(ir.Access access)
{
	switch (access) with (ir.Access) {
	case Private, Public, Protected:
	case Package: // Yes
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
	assert(a.store is null);

	a.store = current.addAlias(a, a.name, current);
}

void gather(ir.Scope current, ir.Variable v, Where where, ir.Function[] functionStack)
{
	assert(v.access.isValidAccess());

	if (functionStack.length > 1) {
		v.oldname = v.name;
		v.name = functionStack[$-1].name ~ v.name;
		functionStack[$-1].renamedVariables ~= v;
	}

	// TODO Move to semantic.
	auto shadowStore = findShadowed(current, v.location, v.name);
	if (shadowStore !is null) {
		throw makeShadowsDeclaration(v, shadowStore.node);
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

void gather(ir.Scope current, ir.Function fn, Where where)
{
	assert(fn.access.isValidAccess());

	if (fn.name !is null) {
		current.addFunction(fn, fn.name);
	}

	if (fn.kind == ir.Function.Kind.Invalid) {
		if (where == Where.TopLevel) {
			fn.kind = ir.Function.Kind.Member;
		} else {
			if (fn.isAbstract) {
				throw makeAbstractHasToBeMember(fn, fn);
			}
			fn.kind = ir.Function.Kind.Function;
		}
	}
}

void gather(ir.Scope current, ir.Struct s, Where where)
{
	assert(s.access.isValidAccess());
	assert(s.myScope !is null);

	current.addType(s, s.name);
}

void gather(ir.Scope current, ir.Union u, Where where)
{
	assert(u.access.isValidAccess());
	assert(u.myScope !is null);

	current.addType(u, u.name);
}

void gather(ir.Scope current, ir.Class c, Where where)
{
	assert(c.access.isValidAccess());
	assert(c.myScope !is null);

	current.addType(c, c.name);
}

void gather(ir.Scope current, ir.Enum e, Where where)
{
	assert(e.access.isValidAccess());
	assert(e.myScope !is null);

	current.addType(e, e.name);
}

void gather(ir.Scope current, ir._Interface i, Where where)
{
	assert(i.access.isValidAccess());
	assert(i.myScope !is null);

	current.addType(i, i.name);
}

void gather(ir.Scope current, ir.MixinFunction mf, Where where)
{
	// @TODO assert(mf.access.isValidAccess());

	current.addTemplate(mf, mf.name);
}

void gather(ir.Scope current, ir.MixinTemplate mt, Where where)
{
	// @TODO assert(mt.access.isValidAccess());

	current.addTemplate(mt, mt.name);
}

void gather(ir.Scope current, ir.UserAttribute ua, Where where)
{
	assert(ua.access.isValidAccess());
	assert(ua.myScope !is null);

	current.addType(ua, ua.name);
}


/*
 *
 * Adding scopes to nodes.
 *
 */

void addScope(ir.Module m)
{
	assert(m.myScope is null);

	string name = m.name.identifiers[$-1].value;
	m.myScope = new ir.Scope(m, name);
}

void addScope(ir.Scope current, ir.Function fn, ir.Type thisType, ir.Function[] functionStack)
{
	fn.myScope = new ir.Scope(current, fn, fn.name);

	if (fn._body !is null) {
		foreach (var; fn.params) {
			if (current.node.nodeType == ir.NodeType.BlockStatement) {
				var.oldname = var.name;
				var.name = fn.name ~ var.name;
			}
			if (var.name !is null) {
				fn.myScope.addValue(var, var.name);
			}
		}
	}

	if (thisType is null || fn.kind == ir.Function.Kind.Function) {
		assert(fn.kind != ir.Function.Kind.Member &&
		       fn.kind != ir.Function.Kind.Destructor &&
		       fn.kind != ir.Function.Kind.Constructor);
		return;
	}

	auto tr = buildTypeReference(thisType.location, thisType,  "__this");

	auto thisVar = new ir.Variable();
	thisVar.location = fn.location;
	thisVar.type = tr;
	thisVar.name = "this";
	thisVar.storage = ir.Variable.Storage.Function;
	// For classes this needs to be set.
	thisVar.useBaseStorage = cast(ir.Class)thisType !is null;

	// Don't add it, it will get added by the variable code.
	fn.thisHiddenParameter = thisVar;
	fn.type.hiddenParameter = true;
}

void addScope(ir.Scope current, ir.BlockStatement bs)
{
	if (bs.myScope !is null) {
		return;
	}
	bs.myScope = new ir.Scope(current, bs, "block");
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
		agg.anonymousVars ~= buildVariableSmart(s.location, s, ir.Variable.Storage.Field, name);
		agg.members.nodes ~= agg.anonymousVars[$-1];
	}
	assert(s.myScope is null);
	s.myScope = new ir.Scope(current, s, s.name);
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
		agg.anonymousVars ~= buildVariableSmart(u.location, u, ir.Variable.Storage.Field, name);
		agg.members.nodes ~= agg.anonymousVars[$-1];
	}	
	assert(u.myScope is null);
	u.myScope = new ir.Scope(current, u, u.name);
}

void addScope(ir.Scope current, ir.Enum e)
{
	assert(e.myScope is null);
	e.myScope = new ir.Scope(current, e, e.name);
}

void addScope(ir.Scope current, ir.Class c, Where where)
{
	if (c.name is null) {
		throw panic(c, "anonymous classes not supported");
	}

	// Identify if this class is the one true Object.
	if (where == Where.Module &&
	    current.name == "object" &&
	    c.name == "Object") {
		auto mod = cast(ir.Module) current.node;
		assert(mod !is null);
		assert(mod.name.identifiers[$-1].value == "object");

		c.isObject = mod.name.identifiers.length == 1;
	}

	assert(c.myScope is null);
	c.myScope = new ir.Scope(current, c, c.name);
}

void addScope(ir.Scope current, ir._Interface i)
{
	if (i.name is null) {
		throw panic(i, "anonymous interfaces not supported");
	}

	assert(i.myScope is null);
	i.myScope = new ir.Scope(current, i, i.name);
}

void addScope(ir.Scope current, ir.UserAttribute ua)
{
	assert(ua.myScope is null);
	ua.myScope = new ir.Scope(current, ua, ua.name);
}


/**
 * Poplate the scops with Variables, Alias, Functions and Types.
 * Adds scopes where needed as well.
 *
 * @ingroup passes passLang
 */
class Gatherer : NullVisitor, Pass
{
protected:
	Where[] mWhere;
	ir.Scope[] mScope;
	ir.Type[] mThis;
	ir.Function[] mFunctionStack;
	ir.Module mModule;

public:
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

	void push(ir.Function fn)
	{
		push(fn.myScope);
		mFunctionStack ~= fn;
	}

	void pop(ir.Function fn)
	{
		pop();
		assert(fn is mFunctionStack[$-1]);
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
		gather(current, v, where, mFunctionStack);
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

	override Status enter(ir.UserAttribute ua)
	{
		addScope(current, ua);
		gather(current, ua, where);
		push(ua.myScope, ua);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		addScope(current, e);
		gather(current, e, where);
		push(e.myScope, e);
		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		auto thisType = where == Where.TopLevel ? this.thisType : null;

		gather(current, fn, where);
		addScope(current, fn, thisType, mFunctionStack);
		push(fn);

		// I don't think this is the right place for this.
		if (fn.isAbstract && fn._body !is null) {
			throw makeAbstractBodyNotEmpty(fn, fn);
		}
		return Continue;
	}

	override Status enter(ir.ForeachStatement fes)
	{
		enter(fes.block);
		foreach (var; fes.itervars) {
			gather(current, var, where, mFunctionStack);
		}
		if (fes.aggregate !is null) acceptExp(fes.aggregate, this);
		if (fes.beginIntegerRange !is null) {
			panicAssert(fes, fes.endIntegerRange !is null);
			acceptExp(fes.beginIntegerRange, this);
			acceptExp(fes.endIntegerRange, this);
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
			gather(current, var, where, mFunctionStack);
		}
		acceptExp(fs.test, this);
		foreach (ref inc; fs.increments) {
			acceptExp(inc, this);
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
			throw panic(bs.location, "block statement outside of function");
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

	void replaceNestedNames(ref string s)
	{
		if (mFunctionStack.length == 0) {
			return;
		}
		/* Names in nested functions are modified to allow for shadowing,
		 * correct strings that point to these renamed declarations
		 * here.
		 */
		foreach (fn; mFunctionStack[0].nestedFunctions) {
			if (s == fn.oldname) {
				s = fn.name;
				return;
			}
		}
		foreach_reverse(fn; mFunctionStack) {
			foreach (var; fn.params) {
				if (s == var.oldname) {
					s = var.name;
					return;
				}
			}
			foreach (var; fn.renamedVariables) {
				if (s == var.oldname) {
					s = var.name;
				}
			}
		}
	}

	override Status enter(ref ir.Exp exp, ir.Typeid tid)
	{
		if (tid.ident.length > 0) {
			replaceNestedNames(tid.ident);
		}
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.IdentifierExp iexp)
	{
		if (!iexp.globalLookup) {
			replaceNestedNames(iexp.value);
		}
		return Continue;
	}

	override Status leave(ir.Module m) { pop(); return Continue; }
	override Status leave(ir.Class c) { pop(c); return Continue; }
	override Status leave(ir.Struct s) { pop(s); return Continue; }
	override Status leave(ir.Union u) { pop(u); return Continue; }
	override Status leave(ir.Enum e) { pop(e); return Continue; }
	override Status leave(ir.Function fn) { pop(fn); return Continue; }
	override Status leave(ir.BlockStatement bs) { pop(); return Continue; }
	override Status leave(ir._Interface i) { pop(i); return Continue; }
	override Status leave(ir.UserAttribute ua) { pop(ua); return Continue; }
}
