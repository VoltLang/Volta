// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.context;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.semantic.languagepass;


class ContextBuilder : NullVisitor, Pass
{
public:
	ir.Scope current;
	LanguagePass languagepass;
	ir.Module thisModule;


public:
	void close()
	{
	}

	void transform(ir.Module m)
	{
		if (m.myScope is null) {
			return;
		}

		thisModule = m;
		accept(m, this);
	}


	/**
	 * The scopes for types, classes, strucs and functions don't have
	 * a name, and for everyone except functions you need to get the scope
	 * from the ir.Node itself.
	 */
	ir.Scope newContext(ir.Node n)
	{
		return current = new ir.Scope(current, n, null);
	}

	/**
	 * Named scopes for imports and packages.
	 */
	ir.Scope newContext(ir.Node n, string name)
	{
		auto newCtx = new ir.Scope(current, n, name);
		current.addScope(n, current, name);
		return current = newCtx;
	}

	void pop()
	{
		current = current.parent;
	}


	/*
	 * New Scopes.
	 */


	override Status enter(ir.Module m)
	{
		assert(m !is null);
		assert(m.myScope is null);
		assert(current is null);
		// Name
		m.myScope = current = new ir.Scope(m, "");
		m.internalScope = new ir.Scope(m, "");

		return Continue;
	}

	override Status leave(ir.Module m)
	{
		assert(current !is null);
		current = null;
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		current.addType(c, c.name);
		c.myScope = newContext(c);

		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		current.addType(i, i.name);
		i.myScope = newContext(i);

		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		current.addType(s, s.name);
		s.myScope = newContext(s);

		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		current.addFunction(fn, fn.name);
		fn.myScope = newContext(fn);
		foreach (var; fn.type.params) {
			fn.myScope.addValue(var, var.name);
		}

		return Continue;
	}
	
	override Status enter(ir.Import i)
	{
		foreach (name; i.names) {
			auto mod = languagepass.getModule(name);
			if (mod is null) {
				throw new CompilerError(name.location, format("cannot find module '%s'.", name));
			}
			
			if (i.bind !is null && i.aliases.length == 0) { // import a = b;
				current.addScope(i, mod.myScope, i.bind.value);
			} else if (i.aliases.length == 0 && i.bind is null) {
				thisModule.importedModules ~= mod;
				thisModule.importedAccess ~= i.access;
			} else if (i.aliases.length > 0) {  // import a : b, c OR import a = b : c, d;
				ir.Scope bindScope;
				if (i.bind !is null) {
					auto newMod = new ir.Module();
					newMod.location = i.bind.location;
					newMod.name = new ir.QualifiedName();
					newMod.name.identifiers ~= i.bind;
					bindScope = new ir.Scope(newMod, "");
					newMod.myScope = bindScope;
				}
				foreach (ii, _alias; i.aliases) {
					string symbolFromImportName, symbolInModuleName;
					if (_alias[1] is null) {
						symbolFromImportName = symbolInModuleName = _alias[0].value;
					} else {
						symbolFromImportName = _alias[1].value;
						symbolInModuleName = _alias[0].value;
					}
					auto store = mod.myScope.getStore(symbolFromImportName);
					if (store is null) {
						throw new CompilerError(format("module '%s' has no symbol '%s'.", mod.name, symbolFromImportName));
					}
					if (i.bind !is null) {
						bindScope.addStore(store, symbolInModuleName);
					} else {
						thisModule.myScope.addStore(store, symbolInModuleName);
					}
				}
				if (i.bind !is null) current.addScope(i, bindScope, i.bind.value);
			}
		}
		return Continue;
	}

	override Status leave(ir.Class c) { pop(); return Continue; }
	override Status leave(ir._Interface i) { pop(); return Continue; }
	override Status leave(ir.Struct s) { pop(); return Continue; }
	override Status leave(ir.Function fn) { pop(); return Continue; }

public:
	this(LanguagePass languagepass)
	{
		this.languagepass = languagepass;
	}
}
