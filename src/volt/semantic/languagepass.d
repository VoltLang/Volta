// Copyright © 2012, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.languagepass;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.errors;

import volt.token.location;

import volt.util.worktracker;

import volt.visitor.debugprinter;
import volt.visitor.prettyprinter;

import volt.semantic.util;
import volt.semantic.classify;
import volt.semantic.lookup;
import volt.semantic.typeinfo;
import volt.semantic.attribremoval;
import volt.semantic.condremoval;
import volt.semantic.gatherer;
import volt.semantic.extyper;
import volt.semantic.manglewriter;
import volt.semantic.importresolver;
import volt.semantic.irverifier;
import volt.semantic.typeidreplacer;
import volt.semantic.newreplacer;
import volt.semantic.llvmlowerer;

import volt.semantic.classresolver;
import volt.semantic.aliasresolver;
import volt.semantic.userattrresolver;


/**
 * Default implementation of
 * @link volt.interfaces.LanguagePass LanguagePass@endlink, replace
 * this if you wish to any of the semantics of the language.
 */
class VoltLanguagePass : LanguagePass
{
public:
	/**
	 * Phases fields.
	 * @{
	 */
	Pass[] postParse;
	Pass[] passes2;
	Pass[] passes3;
	/**
	 * @}
	 */

private:
	WorkTracker mTracker;
	ir.Module[string] mModules;

public:
	this(Settings settings, Frontend frontend, Controller controller)
	{
		super(settings, frontend, controller);

		mTracker = new WorkTracker();

		postParse ~= new ConditionalRemoval(this);
		if (settings.removeConditionalsOnly) {
			return;
		}
		postParse ~= new AttribRemoval(this);
		postParse ~= new Gatherer(this);

		passes2 ~= new ExTyper(this);
		passes2 ~= new IrVerifier();

		passes3 ~= new LlvmLowerer(this);
		passes3 ~= new NewReplacer(this);
		passes3 ~= new TypeidReplacer(this);
		passes3 ~= new MangleWriter(this);
		passes3 ~= new IrVerifier();
	}

	override ir.Module getModule(ir.QualifiedName name)
	{ 
		return controller.getModule(name);
	}


	/*
	 *
	 * Resolver functions.
	 *
	 */


	override void gather(ir.Scope current, ir.BlockStatement bs)
	{
		auto g = new Gatherer(this);
		g.transform(current, bs);
		g.close();
	}

	override void resolve(ir.Scope current, ir.TypeReference tr)
	{
		if (tr.type !is null)
			return;

		auto w = mTracker.add(tr, "resolving type");
		scope (exit)
			w.done();

		tr.type = lookupType(this, current, tr.id);
	}

	override void resolve(ir.Scope current, ir.Variable v)
	{
		if (v.isResolved)
			return;

		auto w = mTracker.add(v, "resolving variable");
		scope (exit)
			w.done();

		resolve(current, v.userAttrs);

		auto e = new ExTyper(this);
		e.transform(current, v);

		v.isResolved = true;
	}

	override void resolve(ir.Scope current, ir.Function fn)
	{
		if ((fn.kind == ir.Function.Kind.Function || (cast(ir.Class) current.node) is null) && fn.isMarkedOverride) {
			throw makeMarkedOverrideDoesNotOverride(fn, fn);
		}
		ensureResolved(this, current, fn.type);
		replaceVarArgsIfNeeded(this, fn);
		resolve(current, fn.userAttrs);
	}

	override void resolve(ir.Alias a)
	{
		if (!a.resolved)
			resolve(a.store);
	}

	override void resolve(ir.Store s)
	{
		auto w = mTracker.add(s.node, "resolving alias");
		scope (exit)
			w.done();

		resolveAlias(this, s);
	}

	override void resolve(ir.Scope current, ir.Attribute a)
	{
		if (!needsResolving(a)) {
			return;
		}

		auto e = new ExTyper(this);
		e.transform(current, a);
	}

	override void resolve(ir.Enum e)
	{
		if (e.resolved) {
			return;
		}

		ensureResolved(this, e.myScope.parent, e.base);
		e.resolved = true;

		// Need to resolve the first member to set the type of the Enum.
		resolve(e.myScope, e.members[0]);
	}

	override void resolve(ir.Scope current, ir.EnumDeclaration ed)
	{
		if (ed.resolved) {
			return;
		}

		auto e = new ExTyper(this);
		e.transform(current, ed);
	}

	override void resolve(ir.Scope current, ir.AAType at)
	{
		ensureResolved(this, current, at.value);
		ensureResolved(this, current, at.key);

		auto base = at.key;

		auto tr = cast(ir.TypeReference)base;
		if (tr !is null) {
			base = tr.type;
		}

		if (base.nodeType() == ir.NodeType.ArrayType) {
			base = (cast(ir.ArrayType)base).base;
		} else if (base.nodeType() == ir.NodeType.StaticArrayType) {
			base = (cast(ir.StaticArrayType)base).base;
		}

		auto st = cast(ir.StorageType)base;
		if (st !is null &&
	  	    (st.type == ir.StorageType.Kind.Immutable ||
		     st.type == ir.StorageType.Kind.Const)) {
			base = st.base;
		}

		auto prim = cast(ir.PrimitiveType)base;
		if (prim !is null) {
			return;
		}

		throw makeInvalidAAKey(at);
	}

	override void doResolve(ir.Struct s)
	{
		resolve(s.myScope.parent, s.userAttrs);
		s.isResolved = true;
	}

	override void doResolve(ir.Union u)
	{
		resolve(u.myScope.parent, u.userAttrs);
		u.isResolved = true;
	}

	override void doResolve(ir.Class c)
	{
		resolve(c.myScope.parent, c.userAttrs);
		fillInParentIfNeeded(this, c);
		c.isResolved = true;
	}

	override void doResolve(ir.UserAttribute ua)
	{
		// Nothing to do here.
		ua.isResolved = true;
	}


	/*
	 *
	 * Actualize functons.
	 *
	 */


	override void doActualize(ir.Struct s)
	{
		super.resolve(s);

		auto w = mTracker.add(s, "actualizing struct");
		scope (exit)
			w.done();

		createAggregateVar(this, s.myScope, s);

		foreach (n; s.members.nodes) {
			auto field = cast(ir.Variable)n;
			if (field is null ||
			    field.storage != ir.Variable.Storage.Field) {
				continue;
			}

			resolve(s.myScope, field);
		}

		s.isActualized = true;

		fileInAggregateVar(this, s.myScope, s);
	}

	override void doActualize(ir.Union u)
	{
		super.resolve(u);

		auto w = mTracker.add(u, "actualizing union");
		scope (exit)
			w.done();

		createAggregateVar(this, u.myScope, u);

		uint accum;
		foreach (n; u.members.nodes) {
			if (n.nodeType == ir.NodeType.Function) {
				throw makeExpected(n, "field");
			}
			auto field = cast(ir.Variable)n;
			if (field is null ||
			    field.storage != ir.Variable.Storage.Field) {
				continue;
			}

			resolve(u.myScope, field);
			auto s = size(u.location, this, field.type);
			if (s > accum) {
				accum = s;
			}
		}

		u.totalSize = accum;
		u.isActualized = true;

		fileInAggregateVar(this, u.myScope, u);
	}

	override void doActualize(ir.Class c)
	{
		super.resolve(c);

		auto w = mTracker.add(c, "actualizing class");
		scope (exit)
			w.done();

		createAggregateVar(this, c.myScope, c);

		resolveClass(this, c);

		foreach (n; c.members.nodes) {
			auto field = cast(ir.Variable)n;
			if (field is null ||
			    field.storage != ir.Variable.Storage.Field) {
				continue;
			}

			resolve(c.myScope, field);
		}

		c.isActualized = true;

		fileInAggregateVar(this, c.myScope, c);
	}

	override void doActualize(ir.UserAttribute ua)
	{
		super.resolve(ua);

		auto w = mTracker.add(ua, "actualizing user attribute");
		scope (exit)
			w.done();

		actualizeUserAttribute(this, ua);
		ua.isActualized = true;
	}


	/*
	 *
	 * Phase functions.
	 *
	 */


	override void phase1(ir.Module m)
	{
		if (m.hasPhase1)
			return;
		m.hasPhase1 = true;

		foreach(pass; postParse)
			pass.transform(m);

		if (settings.removeConditionalsOnly) {
			return;
		}

		// Need to create one for each import since,
		// the import resolver will cause phase1 to be called.
		auto impRes = new ImportResolver(this);
		impRes.transform(m);
	}

	override void phase2(ir.Module[] mods)
	{
		foreach(m; mods) {
			foreach(pass; passes2) {
				pass.transform(m);
			}
		}
	}

	override void phase3(ir.Module[] mods)
	{
		foreach(m; mods) {
			foreach(pass; passes3) {
				pass.transform(m);
			}
		}
	}

	override void close()
	{
		foreach(pass; postParse)
			pass.close();
		foreach(pass; passes2)
			pass.close();
		foreach(pass; passes3)
			pass.close();
	}


	/*
	 *
	 * Random stuff.
	 *
	 */


	private void resolve(ir.Scope current, ir.Attribute[] userAttrs)
	{
		foreach (a; userAttrs) {
			resolve(current, a);
		}
	}
}
