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

void fillInParentIfNeeded(Location loc, LanguagePass lp, ir.Class c, ir.Scope _scope)
{
	if (c.parent !is null) {
		assert(c.parent.identifiers.length == 1);
		/// @todo Correct look up.
		auto store = lookup(loc, lp, _scope, c.parent.identifiers[0].value);
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

ir.Variable[] getClassFields(ir.Class _class)
{
	ir.Variable[] fields;
	if (_class.parentClass !is null) {
		fields ~= getClassFields(_class.parentClass);
	}
	foreach (node; _class.members.nodes) {
		auto asVar = cast(ir.Variable) node;
		if (asVar is null) {
			continue;
		}
		if (asVar.storage != ir.Variable.Storage.None) {
			continue;
		}
		fields ~= copyVariableSmart(asVar.location, asVar);
	}
	return fields;
}

/// Get all the functions in an inheritance chain -- ignore overloading.
ir.Function[] getClassMethods(ir.Class _class)
{
	bool gatherConstructors = _class.userConstructors.length == 0;
	ir.Function[] methods;
	if (_class.parentClass !is null) {
		methods ~= getClassMethods(_class.parentClass);
	}
	foreach (node; _class.members.nodes) {
		auto asFunction = cast(ir.Function) node;
		if (asFunction is null) {
			continue;
		}

		if (asFunction.kind == ir.Function.Kind.Constructor) {
			if (gatherConstructors) {
				_class.userConstructors ~= asFunction;
			}
			continue;
		}

		methods ~= asFunction;
	}

	if (_class.userConstructors.length != 1) {
		throw new CompilerError(_class.location, "at least one constructor is required.");
	}

	return methods;
}

ir.Function[] getClassMethodFunctions(ir.Class _class)
{
	ir.Function[] methods = getClassMethods(_class);

	// Retrieve the types for these functions, taking into account overloading.
	bool[string] definedFunctions;
	size_t outIndex;
	auto outMethods = new ir.Function[methods.length];
	foreach (method; methods) {
		if (auto p = method.name in definedFunctions) {
			continue;
		}
		outMethods[outIndex] = method;
		outIndex++;
		definedFunctions[method.name] = true;
		method.vtableIndex = cast(int)outIndex - 1;
	}
	outMethods.length = outIndex;
	return outMethods;
}

ir.Variable[] getClassMethodTypeVariables(ir.Class _class)
{
	ir.Function[] methods = getClassMethodFunctions(_class);

	ir.Variable[] typeVars;
	foreach (outIndex, method; methods) {
		typeVars ~= buildVariableSmart(method.location, method.type, format("_%s", outIndex));
	}
	return typeVars;
}

ir.Exp[] getClassMethodAddrOfs(ir.Class _class)
{
	ir.Function[] methods = getClassMethodFunctions(_class);

	ir.Exp[] addrs;
	foreach (method; methods) {
		auto eref = buildExpReference(_class.location, method, method.name);
		eref.rawReference = true;
		addrs ~= eref;
	}
	return addrs;
}

ir.Struct getClassLayoutStruct(ir.Class _class, ref ir.Struct vtableStruct)
{
	auto methodTypes = getClassMethodTypeVariables(_class);
	vtableStruct = buildStruct(_class.location, _class.members, _class.myScope, "__Vtable", methodTypes);
	auto vtableVar = buildVariableSmart(_class.location, buildPtrSmart(_class.location, vtableStruct), "__vtable");

	auto fields = getClassFields(_class);
	fields = vtableVar ~ fields;

	return buildStruct(_class.location, _class.members, _class.myScope, "__layoutStruct", fields);
}

void emitVtableVariable(ir.Class _class)
{
	auto addrs = getClassMethodAddrOfs(_class);
	auto assign = new ir.StructLiteral();
	assign.location = _class.location;
	assign.exps = addrs;
	assign.type = copyTypeSmart(_class.location, _class.vtableStruct);

	_class.vtableVariable = buildVariableSmart(_class.location, _class.vtableStruct, "__vtable_instance");
	_class.vtableVariable.storage = ir.Variable.Storage.Global;
	_class.vtableVariable.assign = assign;
	_class.members.nodes ~= _class.vtableVariable;
	_class.myScope.addValue(_class.vtableVariable, _class.vtableVariable.name);
}

/**
 * Fills in Class.layoutStruct and Class.vtableStruct.
 */
void fillInClassLayoutIfNeeded(ir.Class _class)
{
	if (_class.layoutStruct !is null) {
		return;
	}

	ir.Struct vtableStruct;
	_class.layoutStruct = getClassLayoutStruct(_class, vtableStruct);
	_class.vtableStruct = vtableStruct;
	emitVtableVariable(_class);
}
