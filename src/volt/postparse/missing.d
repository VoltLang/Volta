// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012-2016, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
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
 * @ingroup passes passLang
 */
class MissingDeps : ScopeManager, Pass
{
private:
	LanguagePass lp;
	ir.Module mModule;
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
			throw makeNonTopLevelImport(i.loc);
		}

		if (i.isStatic && i.access != ir.Access.Private) {
			throw makeExpected(i.loc, 
				format("static import '%s' to be private", i.name));
		}

		auto mod = lp.getModule(i.name);
		if (mod is null) {
			mStore[i.name.toString()] = true;
		}

		return ContinueParent;
	}
}
