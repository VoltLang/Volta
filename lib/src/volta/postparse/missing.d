/*#D*/
// Copyright © 2012-2017, Bernard Helyer.
// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Module containing the @ref MissingDeps class.
 *
 * @ingroup passPost
 */
module volta.postparse.missing;

import watt.text.format : format;

import ir = volta.ir;

import volta.errors;
import volta.interfaces;
import volta.visitor.visitor;
import volta.visitor.scopemanager;

alias GetMod = ir.Module delegate(ir.QualifiedName);


/*!
 * Looks for missing dependancies via imports.
 *
 * @ingroup passes passLang passPost
 */
class MissingDeps : ScopeManager, Pass
{
private:
	//! The current module we are walking.
	ir.Module mModule;
	//! Set of all the module names that are missing.
	bool[string] mStore;
	//! Where to get modules from.
	GetMod mGetMod;


public:
	this(ErrorSink errSink, GetMod getMod)
	{
		super(errSink);
		mGetMod = getMod;
	}


	/*
	 *
	 * Pass functions.
	 *
	 */

	override void transform(ir.Module m)
	{
		if (!passert(mErr, m, mModule is null)) {
			return;
		}

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
			errorMsg(mErr, i, nonTopLevelImportMsg());
			return ContinueParent;
		}

		if (i.isStatic && i.access != ir.Access.Private) {
			errorExpected(mErr, i, format("static import '%s' to be private", i.names[0]));
			return ContinueParent;
		}

		auto mod = mGetMod(i.names[0]);
		if (mod is null) {
			mStore[i.names[0].toString()] = true;
		}

		return ContinueParent;
	}
}
