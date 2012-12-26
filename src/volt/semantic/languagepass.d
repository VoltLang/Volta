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

/**
 * @defgroup passes Passes
 * @brief Volt is a passes based compiler.
 */

/**
 * @defgroup passLang Language Passes
 * @ingroup passes
 * @brief Language Passes verify and slightly transforms parsed modules.
 *
 * The language passes are devided into 3 main phases:
 * 1. PostParse
 * 2. Exp Type Verification
 * 3. Misc
 *
 * Phase 1, PostParse, works like this:
 * 1. All of the version statements are resolved for the entire module.
 * 2. Then for each Module, Class, Struct, Enum's TopLevelBlock.
 *   1. Apply all attributes in the current block or direct children.
 *   2. Add symbols to scope in the current block or direct children.
 *   3. Then do step a-c for for each child TopLevelBlock that
 *      brings in a new scope (Classes, Enums, Structs).
 * 3. Resolve the imports.
 * 4. Going from top to bottom resolving static if (applying step 2
 *    to the selected TopLevelBlock).
 *
 * Phase 2, ExpTyper, is just a single complex step that resolves and typechecks
 * any expressions, this pass is only run for modules that are called
 * directly by the LanguagePass.transform function, or functions that
 * are invoked by static ifs.
 *
 * Phase 3, Misc, are various lowering and transformation passes, some can
 * inoke Phase 1 and 2 on newly generated code.
 */

/**
 * @defgroup passLower Lowering Passes
 * @ingroup passes
 * @brief Lowers ir before being passed of to backends.
 */

/**
 * Center point for all language passes.
 * @ingroup passes passLang
 */
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

		passes ~= new ConditionalRemoval(settings);
		passes ~= new AttribRemoval();
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
