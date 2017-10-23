/*#D*/
// Copyright © 2012-2017, Bernard Helyer.
// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Module containing the @ref MissingDeps class.
 *
 * @ingroup passPost
 */
module volt.postparse.missing;

import watt.text.format : format;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.scopemanager;


/*!
 * Looks for missing dependancies via imports.
 *
 * @ingroup passes passLang passPost
 */
class MissingDeps : ScopeManager, Pass
{
private:
	//! Link back to @ref LanguagePass.
	LanguagePass lp;
	//! The current module we are walking.
	ir.Module mModule;
	//! Set of all the module names that are missing.
	bool[string] mStore;


public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}


	/*
	 *
	 * Pass functions.
	 *
	 */

	override void transform(ir.Module m)
	{
		assert(mModule is null);

		mModule = m;
		accept(m, this);
		mModule = null;
	}

	override void close()
	{
	}


	/*
	 *
	 * Visitor and our functions.
	 *
	 */

	string[] getMissing()
	{
		version (Volt) {
			return mStore.keys;
		} else {
			return mStore.keys.dup;
		}
	}

	override Status enter(ir.Import i)
	{
		if (current !is mModule.myScope) {
			throw makeNonTopLevelImport(/*#ref*/i.loc);
		}

		if (i.isStatic && i.access != ir.Access.Private) {
			throw makeExpected(/*#ref*/i.loc, 
				format("static import '%s' to be private", i.names[0]));
		}

		auto mod = lp.getModule(i.names[0]);
		if (mod is null) {
			mStore[i.names[0].toString()] = true;
		}

		return ContinueParent;
	}
}
