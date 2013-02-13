// Copyright © 2012, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.gatherer;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;


enum Where
{
	Module,
	TopLevel,
	Function,
}


/*
 *
 * Add named declarations to scopes.
 *
 */


void gather(ir.Scope current, ir.Alias a, Where where)
{
	current.addAlias(a, a.name, current);
}

void gather(ir.Scope current, ir.Variable v, Where where)
{
	current.addValue(v, v.name);

	if (v.storage != ir.Variable.Storage.Invalid) {
		return;
	}

	if (where == Where.Module) {
		throw new CompilerError(v.location, "module level variables must be explicitly global or local.");
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

	/// @todo change this to check for invalid.
	if (fn.kind == ir.Function.Kind.Function && where == Where.TopLevel) {
		fn.kind = ir.Function.Kind.Member;
	}
}

void gather(ir.Scope current, ir.Struct s, Where where)
{
	current.addType(s, s.name);
}

void gather(ir.Scope current, ir.Class c, Where where)
{
	current.addType(c, c.name);
}

void gather(ir.Scope current, ir._Interface i, Where where)
{
	current.addType(i, i.name);
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

void addScope(ir.Scope current, ir.Function fn, ir.Type thisType)
{
	assert(fn.myScope is null);
	fn.myScope = new ir.Scope(current, fn, fn.name);

	foreach (var; fn.type.params) {
		if (var.name !is null) {
			fn.myScope.addValue(var, var.name);
		}
	}

	if (thisType is null) {
		return;
	}

	auto tr = new ir.TypeReference();
	tr.location = thisType.location;
	tr.names ~= "__this";
	tr.type = thisType;

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

void addScope(ir.Scope current, ir.Struct s)
{
	if (s.name is null) {
		throw new CompilerError(s.location, "anonymous structs not supported (yet)");
	}

	assert(s.myScope is null);
	s.myScope = new ir.Scope(current, s, s.name);
}

void addScope(ir.Scope current, ir.Class c)
{
	if (c.name is null) {
		throw new CompilerError(c.location, "anonymous classes not supported");
	}

	assert(c.myScope is null);
	c.myScope = new ir.Scope(current, c, c.name);
}

void addScope(ir.Scope current, ir._Interface i)
{
	if (i.name is null) {
		throw new CompilerError(i.location, "anonymous interfaces not supported");
	}

	assert(i.myScope is null);
	i.myScope = new ir.Scope(current, i, i.name);
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
			mThis = mThis[0 .. $-1];
		}
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
		gather(current, v, where);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		gather(current, c, where);
		addScope(current, c);
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
		gather(current, s, where);
		addScope(current, s);
		push(s.myScope, s);
		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		gather(current, fn, where);
		addScope(current, fn, where == Where.TopLevel ? thisType : null);
		push(fn.myScope);
		return Continue;
	}

	override Status leave(ir.Module m) { pop(); return Continue; }
	override Status leave(ir.Class c) { pop(c); return Continue; }
	override Status leave(ir.Struct s) { pop(s); return Continue; }
	override Status leave(ir.Function fn) { pop(); return Continue; }
	override Status leave(ir._Interface i) { pop(i); return Continue; }
}
