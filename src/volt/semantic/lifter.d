// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.lifter;

import ir = volt.ir.ir;

import volt.interfaces;

	
/**
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
abstract class Lifter
{
public:
	LanguagePass lp;

private:
	ir.Function[ir.NodeID] mStore;
	ir.Module mMod;
	ir.Module[] mMods;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	/**
	 * Resets the lifter and clears all cached functions and modules.
	 */
	void reset()
	{
		version (Volt) {
			mStore = [];
		} else {
			mStore = null;
		}
		mMod = null;
		mMods = null;
	}

	/**
	 * Create a new module to store functions in.
	 *
	 * Does not clear the function cache, so functions can refer
	 * to functions in earlier modules.
	 */
	ir.Module newModule()
	{
		mMod = new ir.Module();
		mMods ~= mMod;

		return mMod;
	}

	/**
	 * Lift or returns a cached copy of the given function.
	 */
	ir.Function lift(ir.Function func)
	{
		assert(mMod !is null);

		ir.Function ret;
		if (mStore.get(func.uniqueId, ret)) {
			return ret;
		}

		return doLift(func);
	}

protected:
	/**
	 * Copies the function declration and adds it to the store.
	 *
	 * The body, in and out contracts are left null and will need to be
	 * copied by the caller. Intended to be used as a helper function.
	 */
	ir.Function copyDeclaration(ir.Function old)
	{
		assert((old.uniqueId in mStore) is null);

		// TODO Need actualize as insted.
		//lp.actualize(old);
		assert(old.isActualized);

		auto func = new ir.Function();
		func.location = old.location;
		// TODO more fields

		mStore[old.uniqueId] = func;
		return func;
	}

	/**
	 * Implemented by child classes, copies the Function into the
	 * current module mMod and applies error checking and transformation
	 * needed for that specific lifter.
	 */
	abstract ir.Function doLift(ir.Function);
}

class CTFELifter : Lifter
{
public:
	this(LanguagePass lp)
	{
		super(lp);
	}


protected:
	override ir.Function doLift(ir.Function old)
	{
		// Copy declaration and add function to store.
		auto func = copyDeclaration(old);

		// TODO copy in, out and body.

		return func;
	}
}

/+
void runExp(ref ir.Exp exp)
{
	rexp := cast(ir.RunExp) exp;
	pfix := cast(ir.Postfix) rexp.value;
	func := getFunctionFromPostfix(pfix);
	dlgt := lp.liftFunction(func);
	static is (typeof(dlgt) == ir.Constant delegate(ir.Constant[] args));

	args : ir.Constant[];
	foreach (exp; pfix.arguments) {
		args ~= evaluate(exp);
	}

	dlgt(args);
}
+/
