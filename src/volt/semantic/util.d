// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.util;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.exceptions;
import volt.interfaces;
import volt.token.location;
import volt.semantic.lookup;
import volt.semantic.typer : getExpType;


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

ir.Type handleNull(ir.Type left, ref ir.Exp right, ir.Type rightType)
{
	if (rightType.nodeType == ir.NodeType.NullType) {
		auto constant = cast(ir.Constant) right;
		if (constant is null) {
			throw CompilerPanic(right.location, "non constant null");
		}

		while (true) switch (left.nodeType) with (ir.NodeType) {
		case PointerType:
			constant.type = buildVoidPtr(right.location);
			right = buildCastSmart(right.location, left, right);
			return copyTypeSmart(right.location, left);
		case ArrayType:
			right = buildArrayLiteralSmart(right.location, left);
			return copyTypeSmart(right.location, left);
		case TypeReference:
			auto tr = cast(ir.TypeReference) left;
			assert(tr !is null);
			left = tr.type;
			continue;
		case Class:
			auto _class = cast(ir.Class) left;
			if (_class !is null) {
				auto t = copyTypeSmart(right.location, _class);
				constant.type = t;
				return t;
			}
			goto default;
		default:
			string emsg = format("can't convert null into '%s'.", to!string(left.nodeType));
			throw new CompilerError(right.location, emsg);
		}
	}
	return null;
}
