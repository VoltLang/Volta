/*#D*/
// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.lifter;

import ir = volta.ir;
import volt.ir.lifter : Lifter;
import volta.util.util : buildQualifiedName;

import volt.errors;
import volt.interfaces;

import volt.visitor.visitor;
import volt.visitor.nodereplace;

import volt.semantic.irverifier;


/*!
 * IR Lifter, aka Liftertron3000, copies and does transformations on IR.
 *
 * This is the base class providing utility functions and a common interface
 * for users. One reason for lifting is that the target we are compiling for
 * is not the same as for the compiler is running on, and as such different
 * backend transformations needs to be done on the IR. Extra validation can
 * also be done while copying.
 *
 * Dost thou even lyft brother.
 */
abstract class SemanticLifter : Lifter
{
public:
	LanguagePass lp;

private:
	struct OldDeclNewDecl
	{
		ir.Declaration oldDecl;
		ir.Declaration newDecl;
		string name;
	}

private:
	ir.Node[ir.NodeID] mStore;
	ir.Module mMod;
	ir.Module[] mMods;
	OldDeclNewDecl[] mDeclsToReplace;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	/*!
	 * Resets the lifter and clears all cached functions and modules.
	 */
	void reset()
	{
		mStore = null;
		mMod = null;
		mMods = null;
	}

	/*!
	 * Completes the module and returns it for consumption.
	 */
	ir.Module completeModule()
	{
		assert(mMod !is null);

		auto ret = mMod;
		mMod = null;
		debug {
			(new IrVerifier()).transform(ret);
		}
		return ret;
	}

	/*!
	 * Lift or returns a cached copy of the given function.
	 */
	override ir.Function lift(ir.Function func)
	{
		auto p = func.uniqueId in mStore;
		if (p !is null) {
			return cast(ir.Function)*p;
		}

		if (mMod is null) {
			newModule();
		}

		return doLift(func);
	}

	/*!
	 * Lift or returns a cached copy of the given variable.
	 */
	override ir.Variable lift(ir.Variable var)
	{
		auto p = var.uniqueId in mStore;
		if (p !is null) {
			return cast(ir.Variable)*p;
		}

		if (mMod is null) {
			newModule();
		}

		return doLift(var);
	}

	/*!
	 * Lift or returns a cached copy of the given function.
	 */
	override ir.FunctionParam lift(ir.FunctionParam fp)
	{
		auto p = fp.uniqueId in mStore;
		if (p !is null) {
			return cast(ir.FunctionParam)*p;
		}

		if (mMod is null) {
			newModule();
		}

		return doLift(fp);
	}

	/*!
	 * Get a lifted node or panic.
	 */
	override ir.Node liftedOrPanic(ir.Node node, string msg)
	{
		auto p = node.uniqueId in mStore;
		if (p !is null) {
			return *p;
		}

		throw panic(node, msg);
	}

	override ir.Class lift(ir.Class old) { throw panic(ir.nodeToString(old)); }
	override ir.Union lift(ir.Union old) { throw panic(ir.nodeToString(old)); }
	override ir.Enum lift(ir.Enum old) { throw panic(ir.nodeToString(old)); }
	override ir.Struct lift(ir.Struct old) { throw panic(ir.nodeToString(old)); }
	override ir._Interface lift(ir._Interface old) { throw panic(ir.nodeToString(old)); }
	override ir.TopLevelBlock lift(ir.TopLevelBlock old) { throw panic(ir.nodeToString(old)); }
	override ir.Alias lift(ir.Alias old) { throw panic(ir.nodeToString(old)); }


protected:
	/*!
	 * Create a new module to store functions in.
	 *
	 * Does not clear the function cache, so functions can refer
	 * to functions in earlier modules.
	 */
	void newModule()
	{
		assert(mMod is null);

		auto name = "CTFETESTMODULE";

		mMod = new ir.Module();
		mMod.name = buildQualifiedName(/*#ref*/mMod.loc, name);
		mMod.children = new ir.TopLevelBlock();
		mMod.children.loc = mMod.loc;
		mMods ~= mMod;
		mMod.myScope = new ir.Scope(mMod, name);
	}

	/*!
	 * Implemented by child classes, copies the function or variable into
	 * the current module mMod and applies error checking and
	 * transformation needed for that specific lifter.
	 */
	ir.Function doLift(ir.Function n) { throw panic(n, "don't know how to lift functions"); }
	ir.Variable doLift(ir.Variable n) { throw panic(n, "don't know how to lift variables"); }
	ir.FunctionParam doLift(ir.FunctionParam n) { throw panic(n, "don't know how to lift function params"); }
}

class CTFELifter : SemanticLifter
{
public:
	this(LanguagePass lp)
	{
		super(lp);
	}


protected:
	override ir.Function doLift(ir.Function old)
	{
		if (old.kind != ir.Function.Kind.Function) {
			throw makeNotAvailableInCTFE(old, "non toplevel functions");
		}
		auto func = new ir.Function(old);
		func.myScope = copyScope(mMod.myScope, func, old.myScope);

		mStore[old.uniqueId] = func;
		mMod.children.nodes ~= func;

		// Replace params and add to mStore
		foreach (ref p; func.params) {
			auto n = copy(p);
			n.func = func;
			mStore[p.uniqueId] = n;
			p = n;
		}

		copyStores(func.myScope, old.myScope);

		func.type = copy(old.type);
		assert(old.nestedFunctions is null);
		assert(old.scopeSuccesses is null);
		assert(old.scopeFailures is null);
		assert(old.scopeExits is null);
		assert(old.inContract is null);
		assert(old.thisHiddenParameter is null);
		assert(old.nestedHiddenParameter is null);
		assert(old.nestedVariable is null);
		assert(old.nestStruct is null);

		if (old._body !is null) {
			func._body = copy(func.myScope, old._body);
		}
		return func;
	}

	override ir.Variable doLift(ir.Variable old)
	{
		auto var = new ir.Variable(old);
		mStore[old.uniqueId] = var;

		var.type = copyType(old.type);
		if (old.assign !is null) {
			var.assign = copyExp(old.assign);
		}

		return var;
	}
}
