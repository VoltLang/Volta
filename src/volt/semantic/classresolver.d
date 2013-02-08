// Copyright © 2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.classresolver;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.interfaces;
import volt.exceptions;

import volt.token.location;

import volt.semantic.lookup;
import volt.semantic.util;


bool needsResolving(ir.Class c)
{
	if (c.layoutStruct is null) {
		return true;
	}
	if (c.parentClass is null && c.parent !is null) {
		return true;
	}

	return false;
}

void resolveClass(LanguagePass lp, ir.Class c)
{
	fillInParentIfNeeded(c.location, lp, c, c.myScope);
	fillInClassLayoutIfNeeded(c);
}


/*
 *
 * Internal functions.
 *
 */


/**
 * Fills in Class.layoutStruct and Class.vtableStruct.
 */
void fillInClassLayoutIfNeeded(ir.Class c)
{
	if (c.layoutStruct !is null) {
		return;
	}

	ir.Struct vtableStruct;
	c.layoutStruct = getClassLayoutStruct(c, vtableStruct);
	c.vtableStruct = vtableStruct;
	emitVtableVariable(c);
}

void fillInParentIfNeeded(Location loc, LanguagePass lp, ir.Class c, ir.Scope _scope)
{
	if (c.parent is null) {
		/// @todo one interface will be parsed into parent, remove it then do this.
		auto mod = cast(ir.Module) c.myScope.parent.node;
		bool inObject = mod !is null && mod.name.identifiers.length == 1 && mod.name.identifiers[0].value == "object";
		if (c.name != "Object" || !inObject) {
			c.parent = buildQualifiedName(loc, ["object", "Object"]);
			c.parentClass = retrieveObject(loc, lp, _scope);
		}
		return;
	}

	foreach (ident; c.parent.identifiers[0 .. $-1]) {
		_scope = lookupScope(loc, lp, _scope, ident.value);
	}

	assert(_scope !is null);
	auto store = lookup(loc, lp, _scope, c.parent.identifiers[$-1].value);
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
		if (asVar.storage != ir.Variable.Storage.Field) {
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
		typeVars ~= buildVariableSmart(method.location, method.type, ir.Variable.Storage.Field, format("_%s", outIndex));
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
	auto vtableVar = buildVariableSmart(_class.location, buildPtrSmart(_class.location, vtableStruct), ir.Variable.Storage.Field, "__vtable");

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

	_class.vtableVariable = buildVariableSmart(_class.location, _class.vtableStruct, ir.Variable.Storage.Global, "__vtable_instance");
	_class.vtableVariable.assign = assign;
	_class.members.nodes ~= _class.vtableVariable;
	_class.myScope.addValue(_class.vtableVariable, _class.vtableVariable.name);
}
