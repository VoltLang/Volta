/*#D*/
// Copyright © 2018, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
//! Code for getting a module from a scope.
module volta.util.moduleFromScope;

import volta.interfaces;
import volta.errors;
import ir = volta.ir;
import volta.ir.location;

ir.Module getModuleFromScope(ref in Location loc, ir.Scope _scope, ErrorSink errSink)
{
	while (_scope !is null) {
		auto m = cast(ir.Module)_scope.node;
		_scope = _scope.parent;

		if (m is null) {
			continue;
		}

		if (_scope !is null) {
			panic(errSink, m, "module scope has parent");
			return null;
		}

		return m;
	}

	panic(errSink, /*#ref*/loc, "scope chain without module base");
	return null;
}