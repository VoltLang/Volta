// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.util;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.exceptions;
import volt.interfaces;
import volt.token.location;
import volt.semantic.lookup : lookup;
import volt.semantic.typer : getExpType;

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

/// If e is a reference to a no-arg property function, turn it into a call.
/// Returns: the CallableType called, if any, null otherwise.
ir.CallableType propertyToCallIfNeeded(Location loc, LanguagePass lp, ref ir.Exp e, ir.Scope current, ir.Postfix[] postfixStack)
{
	auto asRef = cast(ir.ExpReference) e;
	if (asRef !is null) {
		if (asRef.rawReference) {
			return null;
		}
	}

	if (postfixStack.length > 0 && postfixStack[$-1].isImplicitPropertyCall) {
		return null;
	}

	auto t = getExpType(lp, e, current);
	if (t.nodeType == ir.NodeType.FunctionType || t.nodeType == ir.NodeType.DelegateType) {
		auto asCallable = cast(ir.CallableType) t;
		if (asCallable is null) {
			return null;
		}
		if (asCallable.isProperty && asCallable.params.length == 0) {
			auto postfix = buildCall(loc, e, null);
			postfix.isImplicitPropertyCall = true;
			e = postfix;
			return asCallable;
		}
	}
	return null;
}


ir.Node handleNull(ir.Type left, ref ir.Exp right, ir.Type rightType)
{
	if (rightType.nodeType == ir.NodeType.NullType) {
		auto constant = cast(ir.Constant) right;
		if (constant is null) {
			throw CompilerPanic(right.location, "non constant null");
		}
		if (left.nodeType == ir.NodeType.PointerType) {
			constant.type = buildVoidPtr(right.location);
			right = buildCastSmart(right.location, left, right);
			return copyTypeSmart(right.location, left);
		} else if (left.nodeType == ir.NodeType.ArrayType) {
			right = buildArrayLiteralSmart(right.location, left);
			return copyTypeSmart(right.location, left);
		} else {
			throw new CompilerError(right.location, "can only convert null into pointers currently.");
		}
	}
	return null;
}
