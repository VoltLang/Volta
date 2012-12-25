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
 * Lookup something with a scope in another scope.
 * Params:
 *   _scope   = the scope to look in.
 *   name     = the name to look up in _scope.
 *   location = the location to point an error message at.
 *   member   = what you want to look up in the returned scope, for error message purposes.
 * Returns: the Scope found in _scope.
 * Throws: CompilerError if a Scope bearing thing couldn't be found in _scope.
 */
ir.Scope scopeLookup(ir.Scope _scope, string name, Location location, string member)
{
	string emsg = format("expected aggregate with member '%s'.", member);

	auto current = _scope;
	while (current !is null) {
		auto store = current.getStore(name);
		if (store is null) {
			current = current.parent;
			continue;
		}
		if (store.kind != ir.Store.Kind.Type) {
			// !!! this will need to handle more cases some day.
			throw new CompilerError(location, emsg);
		}
		switch (store.node.nodeType) with (ir.NodeType) {
		case Struct:
			auto asStruct = cast(ir.Struct) store.node;
			assert(asStruct !is null);
			return asStruct.myScope;
		case Class:
			auto asClass = cast(ir.Class) store.node;
			assert(asClass !is null);
			return asClass.myScope;
		case Interface:
			auto asInterface = cast(ir._Interface) store.node;
			assert(asInterface !is null);
			return asInterface.myScope;
		default:
			throw new CompilerError(location, emsg);
		}
	}
	throw new CompilerError(location, emsg);
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
