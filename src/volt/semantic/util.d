// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.util;

import std.string : format;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.token.location;
import volt.semantic.lookup : lookup;

void fillInParentIfNeeded(Location loc, ir.Class c, ir.Scope _scope)
{
	if (c.parent !is null) {
		assert(c.parent.identifiers.length == 1);
		/// @todo Correct look up.
		auto store = _scope.lookup(c.parent.identifiers[0].value, loc);
		if (store is null) {
			throw new CompilerError(loc, format("unidentified identifier '%s'.", c.parent));
		}
		if (store.node is null || store.node.nodeType != ir.NodeType.Class) {
			throw new CompilerError(loc, format("'%s' is not a class.", c.parent));
		}
		auto asClass = cast(ir.Class) store.node;
		assert(asClass !is null);
		c.parentClass = asClass;
	}
}
