// Copyright © 2012, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.languagepass;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.exceptions;

import volt.token.location;

import volt.util.worktracker;

import volt.visitor.debugprinter;
import volt.visitor.prettyprinter;

import volt.semantic.util;
import volt.semantic.lookup;
import volt.semantic.attribremoval;
import volt.semantic.condremoval;
import volt.semantic.gatherer;
import volt.semantic.exptyper;
import volt.semantic.manglewriter;
import volt.semantic.importresolver;
import volt.semantic.irverifier;
import volt.semantic.typeidreplacer;
import volt.semantic.newreplacer;
import volt.semantic.llvmlowerer;

import volt.semantic.classresolver;
import volt.semantic.aliasresolver;


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

		passes2 ~= new ExpTyper(this);
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
		ensureResolved(this, current, v.type);
	}

	override void resolve(ir.Store s)
	{
		auto w = mTracker.add(s.node, "resolving alias");
		scope (exit)
			w.done();

		resolveAlias(this, s);
	}

	override void resolve(ir.Struct c)
	{
		// Nothing to do here.
	}

	override void resolve(ir.Class c)
	{
		fillInParentIfNeeded(this, c);
	}

	override void actualize(ir.Struct c)
	{
		// Nothing to do here.
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
}
