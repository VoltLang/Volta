// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.languagepass;

import ir = volt.ir.ir;

import volt.interfaces;

import volt.token.location;

import volt.visitor.debugprinter;
import volt.visitor.prettyprinter;

import volt.semantic.attribremoval;
import volt.semantic.context;
import volt.semantic.condremoval;
import volt.semantic.declgatherer;
import volt.semantic.userresolver;
import volt.semantic.typeverifier;
import volt.semantic.exptyper;
import volt.semantic.manglewriter;
import volt.semantic.importresolver;
import volt.semantic.irverifier;
import volt.semantic.classlowerer;
import volt.semantic.typeidreplacer;
import volt.semantic.newreplacer;
import volt.semantic.llvmlowerer;


/**
 * Default implementation of
 * @link volt.interfaces.LanguagePass LanguagePass@endlink, replace
 * this if you wish to any of the semantics of the language.
 */
class VoltLanguagePass : LanguagePass
{
public:
	Settings settings;
	Controller controller;

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
	ir.Module[string] mModules;

public:
	this(Settings settings, Controller controller)
	{
		this.settings = settings;
		this.controller = controller;

		postParse ~= new ConditionalRemoval(settings);
		postParse ~= new AttribRemoval();
		postParse ~= new ContextBuilder();
		postParse ~= new DeclarationGatherer();

		passes2a ~= new UserResolver();

		passes2b ~= new TypeDefinitionVerifier();
		passes2b ~= new ExpTyper(settings);
		passes2b ~= new IrVerifier();

		passes3a ~= new ClassLowerer(settings);

		passes3b ~= new NewReplacer(settings);
		passes3b ~= new TypeidReplacer(settings);
		passes3b ~= new LlvmLowerer(settings);
		passes3b ~= new MangleWriter();
		passes3b ~= new IrVerifier();
	}

	override ir.Module getModule(ir.QualifiedName name)
	{ 
		return controller.getModule(name);
	}

	override void phase1(ir.Module m)
	{
		if (m.hasPhase1)
			return;
		m.hasPhase1 = true;

		foreach(pass; postParse)
			pass.transform(m);

		// Need to create one for each import since,
		// the import resolver will cause phase1 to be called.
		auto impRes = new ImportResolver(this, settings);
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
