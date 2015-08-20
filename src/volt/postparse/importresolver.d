// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.postparse.importresolver;

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

	void transform(ir.Module m)
	{
		thisModule = m;

		super.enter(m);

		assert(m.children !is null);

		// Only accept imports directly in the module.
		foreach(n; m.children.nodes) {
			if (n.nodeType == ir.NodeType.Import) {
				handleImport(cast(ir.Import)n);
			} else {
				accept(n, this);
			}
		}

		super.leave(m);
	}

	void close()
	{
	}

	override Status enter(ir.Import i)
	{
		throw makeNonTopLevelImport(i.location);
	}

	void handleImport(ir.Import i)
	{
		auto mod = lp.getModule(i.name);
		if (mod is null) {
			throw makeCannotImport(i, i);
		}
		i.targetModule = mod;

		if (i.bind !is null && i.aliases.length == 0) { // import a = b;
			current.addScope(i, mod.myScope, i.bind.value);
		} else if (i.aliases.length == 0 && i.bind is null) { // static import a; OR import a;
			ir.Scope parent = thisModule.myScope;
			foreach (ident; i.name.identifiers[0 .. $-1]) {
				// TODO Instead just create a alias and insert.
				// You could make it specielt type on the Alias
				// so we can get a proper error message, like:
				// "error: import $I from module $M not found."
				auto name = ident.value;
				auto store = lookup(lp, parent, ident.location, name);
				if (store !is null) {
					if (store.s is null) {
						throw makeExpected(store.node.location, "scope");
					}
					parent = store.s;
				} else {
					auto s = new ir.Scope(parent, ident, name);
					parent.addScope(ident, s, name);
					parent = s;
				}
			}
			auto store = lookup(lp, parent, i.location, i.name.identifiers[$-1].value);
			if (store !is null) {
				if (i.isStatic && store.s !is mod.myScope) {
					throw makeExpected(i.location, "unique module");
				}
			} else {
				parent.addScope(i, mod.myScope, i.name.identifiers[$-1].value);
			}
			if (!i.isStatic) {
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
	}
}