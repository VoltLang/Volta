// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.userresolver;

import std.string : format;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.semantic.lookup;
import volt.semantic.classify;

ir.Type typeLookup(ir.Scope _scope, string name, Location location)
{
	auto store = _scope.lookup(name);
	if (store is null) {
		throw new CompilerError(location, format("undefined identifier '%s'.", name));
	}
	if (store.kind != ir.Store.Kind.Type) {
		throw new CompilerError(location, format("%s used as type.", name));
	}
	auto asType = cast(ir.Type) store.node;
	assert(asType !is null);
	return asType;
}

/**
 * Resolves all @link volt.ir.type.TypeReference TypeReferences@endlink.
 *
 * @ingroup passes passLang
 */
class UserResolver : ScopeManager, Pass
{
public:
	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close()
	{
	}

	override Status visit(ir.TypeReference u)
	{
		ir.Scope lookupScope = current;
		ir.Type theType;
		foreach (i, name; u.names) {
			if (i == u.names.length - 1) {
				theType = typeLookup(lookupScope, name, u.location);
				break;
			}
			lookupScope = scopeLookup(lookupScope, name, u.location, u.names[i+1]);
		}
		assert(theType !is null);

		u.type = theType;

		return Continue;
	}
}
