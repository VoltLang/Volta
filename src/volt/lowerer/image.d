/*#D*/
// Copyright © 2013-2017, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2013-2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Holds @ref ImageGatherer and various code for dealing with per image things.
 *
 * @ingroup passLower
 */
module volt.lowerer.image;

import watt.conv : toString;
import watt.text.format : format;
import watt.io.file : read, exists;

import ir = volta.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volta.ir.location;
import volt.visitor.visitor;
import volt.visitor.nodereplace;

import volt.lowerer.array;

import volt.semantic.util;
import volt.semantic.typer;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.nested;
import volt.semantic.classify;
import volt.semantic.classresolver;
import volt.semantic.evaluate;
import volt.semantic.overload;


/*!
 * If func is the main function, add a C main next to it.
 */
void lowerCMain(LanguagePass lp, ir.Module mod, ir.Function func)
{
	func.name = "vmain";
	auto loc = func.loc;

	// Add a function `extern(C) fn main(argc: i32, argv: char**) i32` to this module.
	auto ftype = buildFunctionTypeSmart(/*#ref*/loc, buildInt(/*#ref*/loc));
	ftype.linkage = ir.Linkage.C;
	auto cmain = buildFunction(/*#ref*/loc, mod.myScope, "main", ftype);
	auto argc = addParam(/*#ref*/loc, cmain, buildInt(/*#ref*/loc), "argc");
	auto argv = addParam(/*#ref*/loc, cmain, buildPtr(/*#ref*/loc, buildPtr(/*#ref*/loc, buildChar(/*#ref*/loc))), "argv");
	ir.Status status;
	mod.myScope.addFunction(cmain, cmain.name, /*#out*/status);
	if (status != ir.Status.Success) {
		throw panic(/*#ref*/cmain.loc, "function redefinition");
	}
	mod.children.nodes ~= cmain;

	ir.Exp argcRef = buildExpReference(/*#ref*/loc, argc, argc.name);
	ir.Exp argvRef = buildExpReference(/*#ref*/loc, argv, argv.name);
	ir.Exp vref = buildExpReference(/*#ref*/loc, func, func.name);
	auto call = buildCall(/*#ref*/loc, lp.runMainFunc, [argcRef, argvRef, vref]);
	buildReturnStat(/*#ref*/loc, cmain._body, call);
}

/*!
 * @brief Collects various things that needs to emitted per image.
 *
 * This class collects global & local constructors and destructors and builds
 * arrays that the runtime loops over. It also emits stub code need for the
 * native volt main to work, this is done by calling into the runtime.
 *
 * @ingroup passes passLang passLower
 */
class ImageGatherer : NullVisitor, Pass
{
public:
	//! The language pass.
	LanguagePass lp;
	//! The current module we are operating on.
	ir.Module thisModule;
	//! Numbering of module [c][d]tors.
	uint thisModuleTorNum;
	//! Have we emitted a main function?
	bool emittedMain;
	//! Main functions that we have found.
	ir.Function mainVolt, mainC;
	//! Module prefix.
	string prefix;

	/*!
	 * Array literals to be assigned to the global variables.
	 */
	//! @{
	ir.ArrayLiteral globalConstructors;
	ir.ArrayLiteral globalDestructors;
	ir.ArrayLiteral localConstructors;
	ir.ArrayLiteral localDestructors;
	//! @}


public:
	this(LanguagePass lp)
	{
		this.lp = lp;

		Location loc;
		auto ft = buildFunctionTypeSmart(/*#ref*/loc, buildVoid(/*#ref*/loc));
		auto arrayType = buildArrayType(/*#ref*/loc, ft);
		globalConstructors = buildArrayLiteralSmart(/*#ref*/loc, arrayType);
		globalDestructors = buildArrayLiteralSmart(/*#ref*/loc, arrayType);
		localConstructors = buildArrayLiteralSmart(/*#ref*/loc, arrayType);
		localDestructors = buildArrayLiteralSmart(/*#ref*/loc, arrayType);
	}


	/*
	 *
	 * Pass
	 *
	 */

	//! Collect the tors from @p m and emit extern(C) main if needed.
	override void transform(ir.Module m)
	{
		prefix = "__V_";
		foreach (id; m.name.identifiers) {
			prefix ~= format("%s%s", id.value.length, id.value);
		}

		thisModuleTorNum = 0;
		this.thisModule = m;
		accept(m, this);
	}

	//! Nothing to do.
	override void close()
	{

	}


	/*
	 *
	 * Visitor
	 *
	 */

	//! The emitting code is run on leave.
	override Status leave(ir.Module m)
	{
		if (mainVolt is null && mainC is null) {
			return Continue;
		}

		if (emittedMain) {
			auto n = mainC !is null ? mainC : mainVolt;
			throw makeError(mainC, "multiple main functions found.");
		}

		emittedMain = true;

		if (mainVolt !is null && mainC is null) {
			lowerCMain(lp, thisModule, mainVolt);
		}

		emitVariable(globalConstructors, "global_ctors");
		emitVariable(globalDestructors, "global_dtors");
		emitVariable(localConstructors, "local_ctors");
		emitVariable(localDestructors, "local_dtors");

		mainVolt = null;
		mainC = null;
		return Continue;
	}

	//! Collect any local/global constructors and find main function.
	override Status enter(ir.Function func)
	{
		final switch (func.kind) with (ir.Function.Kind) {
		case GlobalConstructor:
			handleTor(globalConstructors, "global_ctor", func);
			break;
		case GlobalDestructor:
			handleTor(globalDestructors, "global_dtor", func);
			break;
		case LocalConstructor:
			handleTor(localConstructors, "local_ctor", func);
			break;
		case LocalDestructor:
			handleTor(localDestructors, "local_dtor", func);
			break;
		case Constructor, Destructor:
		case GlobalMember, LocalMember, Member:
		case Function, GlobalNested, Nested, Invalid:
			break;
		}

		// If this is not a main function we are done.
		if (func.name != "main") {
			return Continue;
		}

		if (func.type.linkage == ir.Linkage.Volt) {
			mainVolt = func;
		}

		if (func.type.linkage == ir.Linkage.C) {
			mainC = func;
		}

		return Continue;
	}

	//! Helper function that creates a variable and adds it to @ref thisModule.
	void emitVariable(ir.ArrayLiteral arr, string name)
	{
		auto var = buildVariableSmart(/*#ref*/thisModule.loc, arr.type,
			ir.Variable.Storage.Global, name);
		var.mangledName = "__V_" ~ name;
		var.assign = arr;
		thisModule.children.nodes ~= var;
	}

	//! Sets the correct mangled name on the tor and adds it to the ArrayLiteral.
	void handleTor(ir.ArrayLiteral arr, string name, ir.Function func)
	{
		func.mangledName = format("%s_%s_%s", prefix, name, thisModuleTorNum++);
		func.kind = ir.Function.Kind.Function;

		if (thisModule.name.identifiers[0].value == "vrt") {
			throw makeError(func, "global/local [d][c]tor in runtime.");
		}

		arr.exps ~= buildExpReference(/*#ref*/func.loc, func);
	}
}
