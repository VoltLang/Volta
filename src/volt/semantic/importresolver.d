// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.importresolver;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volt.semantic.lookup;
import volt.visitor.visitor;
import volt.visitor.scopemanager;


/**
 * Resolves imports on a single module.
 *
 * @ingroup passes passLang
 */
class ImportResolver : ScopeManager, Pass
{
public:
	LanguagePass lp;
	ir.Module thisModule;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	override void transform(ir.Module m)
	{
		thisModule = m;
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.Import i)
	{
		auto mod = lp.getModule(i.name);
		if (mod is null) {
			throw makeCannotImport(i, i);
		}
		i.targetModule = mod;

		if (i.bind !is null && i.aliases.length == 0) { // import a = b;
			current.addScope(i, mod.myScope, i.bind.value);

		} else if (i.aliases.length == 0 && i.bind is null) { // static import a; OR import a;
			if (i.isStatic) {
				assert(i.name.identifiers.length == 1);
				thisModule.myScope.addScope(i, mod.myScope, i.name.identifiers[0].value);
			} else {
				thisModule.myScope.importedModules ~= mod;
				thisModule.myScope.importedAccess ~= i.access;
			}

		} else if (i.aliases.length > 0) {  // import a : b, c OR import a = b : c, d;
			ir.Scope bindScope;

			if (i.bind !is null) {
				bindScope = new ir.Scope(null, i, i.bind.value);
				current.addScope(i, bindScope, i.bind.value);
			} else {
				bindScope = thisModule.myScope;
			}

			foreach (ii, _alias; i.aliases) {
				ir.Alias a;
				if (_alias[1] is null) {
					a = buildAlias(_alias[0].location, _alias[0].value, _alias[0].value);
				} else {
					a = buildAliasSmart(_alias[0].location, _alias[0].value, _alias[1]);
				}
				bindScope.addAlias(a, a.name, mod.myScope);
			}
		}

		return Continue;
	}
}
