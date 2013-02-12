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
import volt.semantic.userresolver;
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
	 * Phase 1 fields.
	 * @{
	 */
	Pass[] postParse;
	/**
	 * @}
	 */

	/**
	 * Phase 2 fields.
	 * @{
	 */
	Pass[] passes2a;
	Pass[] passes2b;
	/**
	 * @}
	 */

	/**
	 * Phase 3 fields.
	 * @{
	 */
	Pass[] passes3a;
	Pass[] passes3b;
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

		passes2a ~= new UserResolver(this);

		passes2b ~= new ExpTyper(this);
		passes2b ~= new IrVerifier();

		passes3b ~= new LlvmLowerer(this);
		passes3b ~= new NewReplacer(this);
		passes3b ~= new TypeidReplacer(this);
		passes3b ~= new MangleWriter(this);
		passes3b ~= new IrVerifier();
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


	override void resolveTypeReference(ir.Scope current, ir.TypeReference tr)
	{
		if (tr.type !is null)
			return;

		auto w = mTracker.add(tr, "resolving type");
		scope (exit)
			w.done();

		tr.type = lookupType(this, current, tr.id);
	}

	override void resolveAlias(ir.Store s)
	{
		auto w = mTracker.add(s.node, "resolving alias");
		scope (exit)
			w.done();

		.resolveAlias(this, s);
	}

	override void resolveStruct(ir.Struct c)
	{
		// Nothing to do here.
	}

	override void resolveClass(ir.Class c)
	{
		if (!needsResolving(c))
			return;

		auto w = mTracker.add(c, "resolving class");
		scope (exit)
			w.done();

		.resolveClass(this, c);
	}

	override void gather(ir.Scope current, ir.BlockStatement bs)
	{
		auto g = new Gatherer(this);
		g.transform(current, bs);
		g.close();
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
			foreach(pass; passes2a) {
				pass.transform(m);
			}
		}

		foreach(m; mods) {
			foreach(pass; passes2b) {
				pass.transform(m);
			}
		}
	}

	override void phase3(ir.Module[] mods)
	{
		foreach(m; mods) {
			foreach(pass; passes3a) {
				pass.transform(m);
			}
		}

		foreach(m; mods) {
			foreach(pass; passes3b) {
				pass.transform(m);
			}
		}
	}

	override void close()
	{
		foreach(pass; passes2b)
			pass.close();
	}
}
