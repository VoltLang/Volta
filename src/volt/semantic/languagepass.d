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


class LanguagePass : Pass
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

		passes ~= new AttribRemoval();
		passes ~= new ConditionalRemoval(settings);
		passes ~= new ContextBuilder();
		passes ~= new ImportResolver(this, cast(ContextBuilder) passes[$-1]);
		passes ~= new DeclarationGatherer();
		passes ~= new UserResolver();
		passes ~= new TypeDefinitionVerifier();
		passes ~= new ExpTyper(settings);
		passes ~= new ReferenceReplacer();
		passes ~= new ArrayLowerer(settings);
		passes ~= new MangleWriter();
		passes ~= new IrVerifier();

		if (!settings.noBackend && settings.outputFile is null) {
			passes ~= new DebugPrintVisitor("Running DebugPrintVisitor:");
			passes ~= new PrintVisitor("Running PrintVisitor:");
		}
	}

	override void transform(ir.Module m)
	{
		foreach(pass; passes)
			pass.transform(m);
	}

	override void close()
	{
		foreach(pass; passes)
			pass.close();
	}

	/**
	 * Helper function, just routed to the controller.
	 */
	ir.Module getModule(ir.QualifiedName name)
	{
		return controller.getModule(name);
	}
}
