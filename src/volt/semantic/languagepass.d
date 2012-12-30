// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.languagepass;

import ir = volt.ir.ir;

import volt.interfaces;

import volt.token.location;

import volt.visitor.print;
import volt.visitor.debugprint;

import volt.semantic.attribremoval;
import volt.semantic.context;
import volt.semantic.condremoval;
import volt.semantic.declgatherer;
import volt.semantic.userresolver;
import volt.semantic.typeverifier;
import volt.semantic.exptyper;
import volt.semantic.refrep;
import volt.semantic.arraylowerer;
import volt.semantic.manglewriter;
import volt.semantic.importresolver;
import volt.semantic.irverifier;
import volt.semantic.thisinserter;
import volt.semantic.classlowerer;


/**
 * Default implementation of
 * @link volt.interfaces.LanguagePass LanguagePass@endlink, replace
 * this if you wish to any of the semantics of the language.
 */
class VoltLanguagePass : LanguagePass
{
public:
	Pass[] passes;
	Settings settings;
	Controller controller;

private:
	ir.Module[string] mModules;

public:
	this(Settings settings, Controller controller)
	{
		this.settings = settings;
		this.controller = controller;

		auto contextBuilder = new ContextBuilder();

		passes ~= new ConditionalRemoval(settings);
		passes ~= new AttribRemoval();
		passes ~= contextBuilder;
		passes ~= new ImportResolver(this, contextBuilder, settings);
		passes ~= new DeclarationGatherer();
		passes ~= new UserResolver();
		passes ~= new TypeDefinitionVerifier();
		passes ~= new ExpTyper(settings);
		passes ~= new ReferenceReplacer();
		passes ~= new ArrayLowerer(settings);
		passes ~= new ClassLowerer();
		passes ~= new ThisInserter();	
		passes ~= new MangleWriter();
		passes ~= new IrVerifier();

		if (!settings.noBackend && settings.outputFile is null) {
			passes ~= new DebugPrintVisitor("Running DebugPrintVisitor:");
			passes ~= new PrintVisitor("Running PrintVisitor:");
		}
	}

	override ir.Module getModule(ir.QualifiedName name)
	{
		return controller.getModule(name);
	}

	override void phase1(ir.Module m)
	{

	}

	override void phase2(ir.Module m)
	{
		foreach(pass; passes)
			pass.transform(m);
	}

	override void close()
	{
		foreach(pass; passes)
			pass.close();
	}
}
