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

	override void resolve(ir.Struct s)
	{
		resolve(s.myScope.parent, s.userAttrs);
	}

	override void resolve(ir.Union u)
	{
		resolve(u.myScope.parent, u.userAttrs);
	}

	override void resolve(ir.Class c)
	{
		resolve(c.myScope.parent, c.userAttrs);
		fillInParentIfNeeded(this, c);
	}

	override void resolve(ir.Scope current, ir.Attribute a)
	{
		if (!needsResolving(a)) {
			return;
		}

		auto e = new ExTyper(this);
		e.transform(current, a);
	}

	override void resolve(ir.UserAttribute ua)
	{
		// Nothing to do here.
	}

	override void resolve(ir.Enum e)
	{
		if (e.resolved)
			return;

		ensureResolved(this, e.myScope.parent, e.base);
		e.resolved = true;
	}

	override void resolve(ir.Scope current, ir.EnumDeclaration ed)
	{
		auto e = new ExTyper(this);
		e.transform(current, ed);
	}

	override void actualize(ir.Struct c)
	{
		// Nothing to do here.
	}

	override void actualize(ir.Union u)
	{
		if (u.actualized)
			return;

		auto w = mTracker.add(u, "actualizing union");
		scope (exit)
			w.done();

		foreach (n; u.members.nodes) {
			if (n.nodeType == ir.NodeType.Function) {
				throw makeExpected(n, "field");
			}
			auto field = cast(ir.Variable)n;
			if (field is null) {
				continue;
			}

			resolve(u.myScope, field);
		}

		u.totalSize = size(u.location, this, u);
		u.actualized = true;
	}

	override void actualize(ir.Class c)
	{
		if (!needsResolving(c))
			return;

		auto w = mTracker.add(c, "actualizing class");
		scope (exit)
			w.done();

		resolveClass(this, c);
	}

	override void actualize(ir.UserAttribute ua)
	{
		if (!needsActualizing(ua))
			return;

		auto w = mTracker.add(ua, "actualizing user attribute");
		scope (exit)
			w.done();

		actualizeUserAttribute(this, ua);
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
