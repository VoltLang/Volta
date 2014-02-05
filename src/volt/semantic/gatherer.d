// Copyright © 2012, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.gatherer;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;
import volt.semantic.lookup;
import volt.semantic.nested;


enum Where
{
	Module,
	TopLevel,
	Function,
}

ir.Store findShadowed(LanguagePass lp, ir.Scope _scope, Location loc, string name)
{
	// BlockStatements attached directly to a function have their .node set to that function.
	if (_scope.node.nodeType != ir.NodeType.Function && _scope.node.nodeType != ir.NodeType.BlockStatement) {
		return null;
	}

	auto store = lookupOnlyThisScope(lp, _scope, loc, name);
	if (store !is null) {
		return store;
	}

	if (_scope.parent !is null) {
		if (_scope.node.nodeType == ir.NodeType.Function && _scope.parent.node.nodeType == ir.NodeType.Function) {
			return null;
		}
		return findShadowed(lp, _scope.parent, loc, name);
	} else {
		return null;
	}
}

/*
 *
 * Add named declarations to scopes.
 *
 */

void gather(ir.Scope current, ir.EnumDeclaration e, Where where)
{
	current.addEnumDeclaration(e);
}

void gather(ir.Scope current, ir.Alias a, Where where)
{
	assert(a.store is null);
	a.store = current.addAlias(a, a.name, current);
}

void gather(LanguagePass lp, ir.Scope current, ir.Variable v, Where where, ir.Function[] functionStack)
{
	if (functionStack.length > 1) {
		v.oldname = v.name;
		v.name = functionStack[$-1].name ~ v.name;
		functionStack[$-1].renamedVariables ~= v;
	}

	auto shadowStore = findShadowed(lp, current, v.location, v.name);
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
	current.addType(s, s.name);
}

void gather(ir.Scope current, ir.Union u, Where where)
{
	current.addType(u, u.name);
}

void gather(ir.Scope current, ir.Class c, Where where)
{
	current.addType(c, c.name);
}

void gather(ir.Scope current, ir.Enum e, Where where)
{
	current.addType(e, e.name);
}

void gather(ir.Scope current, ir._Interface i, Where where)
{
	current.addType(i, i.name);
}

void gather(ir.Scope current, ir.MixinFunction mf, Where where)
{
	current.addTemplate(mf, mf.name);
}

void gather(ir.Scope current, ir.MixinTemplate mt, Where where)
{
	current.addTemplate(mt, mt.name);
}

void gather(ir.Scope current, ir.UserAttribute ua, Where where)
{
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

	if (current.node.nodeType == ir.NodeType.BlockStatement) {
		auto ns = functionStack[0].nestStruct;
		assert(ns !is null);
		auto tr = buildTypeReference(ns.location, ns, "__Nested");
		auto decl = buildVariable(fn.location, tr, ir.Variable.Storage.Function, "__nested");
		if (fn.nestedHiddenParameter is null) {
			// XXX: Note __nested is not added to any scope.
			// XXX: Instead make sure that nestedHiddenParameter is visited (and as such visited)
			fn.nestedHiddenParameter = decl;
			fn.nestedVariable = decl;
			fn.nestStruct = ns;
			fn.type.hiddenParameter = true;
		}
	}

	if (thisType is null || fn.kind == ir.Function.Kind.Function) {
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
public:
	LanguagePass lp;

protected:
	Where[] mWhere;
	ir.Scope[] mScope;
	ir.Type[] mThis;
	ir.Function[] mFunctionStack;
	ir.Module mModule;
	ir.WithStatement[] mWithStatements;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	override void close()
	{
	}

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

	/*
	 *
	 * Helpers.
	 *
	 */

	void push(ir.Scope s, ir.Type thisType = null)
	{
		s.withStatements = mWithStatements;
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
		gather(lp, current, v, where, mFunctionStack);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		gather(current, c, where);
		addScope(current, c, where);
		push(c.myScope, c);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		gather(current, i, where);
		addScope(current, i);
		push(i.myScope, i);
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		addScope(current, s);
		gather(current, s, where);
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
		gather(current, ua, where);
		addScope(current, ua);
		push(ua.myScope, ua);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		gather(current, e, where);
		addScope(current, e);
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
			gather(lp, current, var, where, mFunctionStack);
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
			gather(lp, current, var, where, mFunctionStack);
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
		emitNestedStructs(mFunctionStack[$-1], bs);
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

	override Status enter(ir.WithStatement ws)
	{
		mWithStatements ~= ws;
		return Continue;
	}

	override Status leave(ir.WithStatement ws)
	{
		if (mWithStatements[$-1] !is ws) {
			throw panic(ws.location, "invalid layout");
		}
		mWithStatements = mWithStatements[0 .. $-1];
		return Continue;
	}

	override Status enter(ir.SwitchStatement ss)
	{
		foreach (withExp; ss.withs) {
			mWithStatements ~= buildWithStatement(withExp.location, copyExp(withExp));
		}
		return Continue;
	}

	override Status leave(ir.SwitchStatement ss)
	{
		if (mWithStatements.length < ss.withs.length) {
			throw panic(ss.location, "invalid layout");
		}
		mWithStatements = mWithStatements[0 .. $-ss.withs.length];
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
		replaceNestedNames(iexp.value);
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
