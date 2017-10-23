/*#D*/
// Copyright © 2012-2017, Bernard Helyer.
// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Module containing the @ref ImportResolver class.
 *
 * @ingroup passPost
 */
module volt.postparse.importresolver;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.semantic.lookup : getModuleFromScope;
import gatherer = volt.postparse.gatherer;


/*!
 * Resolves imports on a single module.
 *
 * @ingroup passes passLang passPost
 */
class ImportResolver : ScopeManager, Pass
{
private:
	LanguagePass lp;
	ir.Module mModule;


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

	override Status enter(ir.Import i)
	{
		if (current !is mModule.myScope) {
			throw makeNonTopLevelImport(/*#ref*/i.loc);
		}

		if (i.isStatic && i.access != ir.Access.Private) {
			throw makeExpected(/*#ref*/i.loc, 
				format("static import '%s' to be private", i.names[0]));
		}

		foreach (name; i.names) {
			auto mod = lp.getModule(name);
			if (mod is null) {
				throw makeCannotImport(i, name.toString());
			}
			if (mod.isAnonymous) {
				throw makeCannotImportAnonymous(i, name.toString());
			}
			i.targetModules ~= mod;
		}

		if (i.aliases.length > 0) {
			// import a : b, c OR import a = b : c, d;
			handleAliases(i);
		} else if (i.bind !is null) {
			// import a = b;
			handleRebind(i);
		} else {
			// static import a; OR import a;
			handleRegularAndStatic(i);
		}

		return ContinueParent;
	}

	/*!
	 * Takes a import that maps the module to a symbol in the current scope.
	 *
	 * import a = b;
	 */
	void handleRebind(ir.Import i)
	{
		// TODO We should not use mod.myScope here,
		// but intead link directly to the module.
		ir.Scope[] scopes;
		foreach (mod; i.targetModules) {
			gatherer.addScope(mod);
			assert(mod.myScope !is null);
			scopes ~= mod.myScope;
		}

		auto store = current.getStore(i.bind.value);
		if (store !is null) {
			if (store.fromImplicitContextChain) {
				current.remove(i.bind.value);
			} else {
				throw makeRedefines(/*#ref*/i.loc, /*#ref*/store.node.loc, i.bind.value);
			}
		}
		if (scopes.length == 1) {
			store = current.addScope(i, scopes[0], i.bind.value);
		} else {
			store = current.addMultiScope(i, scopes, i.bind.value);
		}
		store.importBindAccess = i.access;
	}

	/*!
	 * Handles a import with symbol aliases.
	 *
	 * import a : b, c;
	 * import a = b : c, d;
	 */
	void handleAliases(ir.Import i)
	{
		panicAssert(i, i.targetModules.length == 1);
		panicAssert(i, i.names.length == i.targetModules.length);
		auto mod = i.targetModules[0];

		auto bindScope = current;
		if (i.bind !is null) {
			bindScope = buildOrReturnScope(bindScope, i.bind, i.bind.value, false/*is low prio?*/);
		} else {
			assert(current is mModule.myScope);
		}

		auto parentMod = getModuleFromScope(/*#ref*/i.loc, current);
		foreach (ii, _alias; i.aliases) {
			ir.Alias a;

			if (_alias[1] is null) {
				a = buildAlias(/*#ref*/_alias[0].loc, _alias[0].value, _alias[0].value);
			} else {
				a = buildAliasSmart(/*#ref*/_alias[0].loc, _alias[0].value, _alias[1]);
			}

			// `private import a : func` should conflict with a public function of name 'func' in the importing module.
			auto ret = parentMod.myScope.getStore(a.name);//lookupInGivenScopeOnly(lp, parentMod.myScope, i.loc, a.name);
			if (ret !is null && ret.functions.length > 0) {
				foreach (func; ret.functions) {
					if (func.access != i.access) {
						throw makeOverloadedFunctionsAccessMismatch(i.access, a, func);
					}
				}
			}

			// Setup where we should look.
			a.lookScope = null;
			a.lookModule = mod;
			a.store = bindScope.addAlias(a, a.name);
			a.store.importBindAccess = i.access;
		}
	}

	/*!
	 * Most common imports.
	 *
	 * import a;
	 * static import a;
	 */
	void handleRegularAndStatic(ir.Import i)
	{
		panicAssert(i, i.targetModules.length == 1);
		auto mod = i.targetModules[0];

		// TODO We should not use mod.myScope here,
		// but intead link directly to the module.
		gatherer.addScope(mod);
		assert(mod.myScope !is null);

		// Where we add the module binding.
		ir.Scope parent = mModule.myScope;

		// Build the chain of scopes for the import.
		// import 'foo.bar.pkg'.mod;
		foreach (ident; i.names[0].identifiers[0 .. $-1]) {
			parent = buildOrReturnScope(parent, ident, ident.value, !i.isStatic/*is low prio?*/);
		}

		// Build the final level.
		// import foo.bar.pkg.'mod';
		auto store = parent.getStore(i.names[0].identifiers[$-1].value);
		if (store !is null) {
			if (i.isStatic && store.myScope !is mod.myScope) {
				throw makeExpected(/*#ref*/i.loc, "unique module");
			}
		} else {
			parent.addScope(i, mod.myScope, i.names[0].identifiers[$-1].value);
		}

		// Add the module to the list of imported modules.
		if (!i.isStatic) {
			mModule.myScope.importedModules ~= mod;
			mModule.myScope.importedAccess ~= i.access;
		}
	}

	/*!
	 * Used for adding in scopes from static imports
	 *
	 * If scope of `name` exists in `parent`, that will be used.
	 * Otherwise one will be created, see the `lowPriority` parameter
	 * for behaviour when a non-scope store of `name` already exists
	 * in `parent`.
	 *
	 * @Param parent The scope to build in.
	 * @Param node The node that introduces the new scope.
	 * @Param name The name of the scope to add.
	 * @Param lowPriority If `true`, the scope will not overwrite a non symbol
	 * scope that already exists. If `false`, such a scope existing will be an error.
	 */
	ir.Scope buildOrReturnScope(ir.Scope parent, ir.Node node, string name, bool lowPriority)
	{
		auto store = parent.getStore(name);
		if (store !is null && (store.myScope !is null || !lowPriority)) {
			// TODO Better error checking here,
			// we could be adding to aggregates here.
			if (store.myScope is null) {
				throw makeExpected(/*#ref*/node.loc, "scope");
			}
			return store.myScope;
		} else {
			auto s = new ir.Scope(parent, node, name, parent.nestedDepth);
			if (store is null || !lowPriority) {
				store = parent.addScope(node, s, name);
				store.fromImplicitContextChain = lowPriority;
			}
			parent = s;
		}
		return parent;
	}
}
