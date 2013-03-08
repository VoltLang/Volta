// Copyright © 2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.classresolver;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.interfaces;
import volt.exceptions;

import volt.token.location;

import volt.semantic.classify;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.util;


bool needsResolving(ir.Class c)
{
	if (c.layoutStruct is null) {
		return true;
	}
	if (!c.isObject && c.parentClass is null) {
		return true;
	}

	return false;
}

void resolveClass(LanguagePass lp, ir.Class c)
{
	fillInParentIfNeeded(lp, c);

	if (!c.isObject) {
		lp.actualize(c.parentClass);
	}

	fillInClassLayoutIfNeeded(c, lp);
}

bool rewriteSuperIfNeeded(ref ir.Exp e, ir.Postfix p, ir.Scope _scope, LanguagePass lp)
{
	auto ident = cast(ir.IdentifierExp) p.child;
	if (ident is null) {
		return false;
	}

	if (ident.value != "super") {
		return false;
	}

	ir.Scope dummyScope;
	ir.Class _class;
	if (!getFirstClass(_scope, dummyScope, _class)) {
		throw new CompilerError(ident.location, "super only valid inside classes.");
	}
	_class = _class.parentClass;
	assert(_class !is null);


	if (p.op == ir.Postfix.Op.Call) {
		return rewriteSuperCallIfNeeded(e, p, _scope, lp, _class);
	} else if (p.op == ir.Postfix.Op.Identifier) {
		return rewriteSuperIdentifierIfNeeded(e, p, _scope, lp, _class);
	} else {
		throw new CompilerError(e.location, "invalid use of super.");
	}
}

bool rewriteSuperIdentifierIfNeeded(ref ir.Exp e, ir.Postfix p, ir.Scope _scope, LanguagePass lp, ir.Class _class)
{
	assert(p.op == ir.Postfix.Op.Identifier);
	auto thisVar = getThisVar(p.location, lp, _scope);
	p.child = buildCastSmart(p.location, _class, buildExpReference(p.location, thisVar, "this"));
	return true;
}

bool rewriteSuperCallIfNeeded(ref ir.Exp e, ir.Postfix p, ir.Scope _scope, LanguagePass lp, ir.Class _class)
{
	assert(p.op == ir.Postfix.Op.Call);

	auto asFunction = cast(ir.Function) _scope.node;
	if (asFunction is null) {
		throw new CompilerError(p.location, "super call outside of function.");
	}
	asFunction.explicitCallToSuper = true;

	auto thisVar = getThisVar(p.location, lp, _scope);
	auto thisRef = buildExpReference(thisVar.location, thisVar, "this");

	assert(_class.userConstructors.length == 1);

	p.child = buildCreateDelegate(p.location, thisRef, buildExpReference(p.location, _class.userConstructors[0], _class.userConstructors[0].name));
	return true;
}


/*
 *
 * Internal functions.
 *
 */


/**
 * Fills in Class.layoutStruct and Class.vtableStruct.
 */
void fillInClassLayoutIfNeeded(ir.Class c, LanguagePass lp)
{
	if (c.layoutStruct !is null) {
		return;
	}

	ir.Struct vtableStruct;
	c.layoutStruct = getClassLayoutStruct(c, lp, vtableStruct);
	c.vtableStruct = vtableStruct;
	emitVtableVariable(lp, c);
}

void fillInParentIfNeeded(LanguagePass lp, ir.Class c)
{
	if (c.isObject) {
		return;
	}

	ir.Class parent;

	/// @todo one interface will be parsed into parent, remove it then do this.
	if (c.parent is null) {
		c.parent = buildQualifiedName(c.location, ["object", "Object"]);
		parent = retrieveObject(lp, c.myScope.parent, c.location);
	} else {
		// Use surrounding scope, and not this unresolved class.
		parent = cast(ir.Class) lookupType(lp, c.myScope.parent, c.parent);
		if (parent is null) {
			throw new CompilerError(c.parent.location, format("'%s' is not a class.", c.parent.toString));
		}
	}

	c.parentClass = parent;
}

ir.Variable[] getClassFields(LanguagePass lp, ir.Class _class)
{
	ir.Variable[] fields;
	if (_class.parentClass !is null) {
		fields ~= getClassFields(lp, _class.parentClass);
	}
	foreach (node; _class.members.nodes) {
		auto asVar = cast(ir.Variable) node;
		if (asVar is null) {
			continue;
		}
		if (asVar.storage != ir.Variable.Storage.Field) {
			continue;
		}
		lp.resolve(_class.myScope, asVar);
		fields ~= copyVariableSmart(asVar.location, asVar);
	}
	return fields;
}

/// Get all the functions in an inheritance chain -- ignore overloading.
ir.Function[] getClassMethods(LanguagePass lp, ir.Class _class)
{
	bool gatherConstructors = _class.userConstructors.length == 0;
	ir.Function[] methods;
	if (_class.parentClass !is null) {
		methods ~= getClassMethods(lp, _class.parentClass);
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

		lp.resolve(asFunction);

		methods ~= asFunction;
	}

	if (_class.userConstructors.length != 1) {
		throw new CompilerError(_class.location, "at least one constructor is required.");
	}

	return methods;
}

ir.Function[] getClassMethodFunctions(LanguagePass lp, ir.Class _class)
{
	ir.Function[] methods = getClassMethods(lp, _class);

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

ir.Variable[] getClassMethodTypeVariables(LanguagePass lp, ir.Class _class)
{
	ir.Function[] methods = getClassMethodFunctions(lp, _class);

	ir.Variable[] typeVars;
	foreach (outIndex, method; methods) {
		typeVars ~= buildVariableSmart(method.location, method.type, ir.Variable.Storage.Field, format("_%s", outIndex));
	}
	return typeVars;
}

ir.Exp[] getClassMethodAddrOfs(LanguagePass lp, ir.Class _class)
{
	ir.Function[] methods = getClassMethodFunctions(lp, _class);

	ir.Exp[] addrs;
	foreach (method; methods) {
		auto eref = buildExpReference(_class.location, method, method.name);
		eref.rawReference = true;
		addrs ~= eref;
	}
	return addrs;
}

ir.Struct getClassLayoutStruct(ir.Class _class, LanguagePass lp, ref ir.Struct vtableStruct)
{
	auto methodTypes = getClassMethodTypeVariables(lp, _class);
	auto tinfo = retrieveTypeInfo(lp, _class.myScope, _class.location);
	auto tinfos = buildVariableSmart(_class.location, buildArrayTypeSmart(_class.location, tinfo), ir.Variable.Storage.Field, "tinfos");

	vtableStruct = buildStruct(_class.location, _class.members, _class.myScope, "__Vtable", tinfos ~ methodTypes);
	auto vtableVar = buildVariableSmart(_class.location, buildPtrSmart(_class.location, vtableStruct), ir.Variable.Storage.Field, "__vtable");

	auto fields = getClassFields(lp, _class);
	fields = vtableVar ~ fields;

	auto layoutStruct = buildStruct(_class.location, _class.members, _class.myScope, "__layoutStruct", fields);
	layoutStruct.loweredNode = _class;
	return layoutStruct;
}

ir.Class[] getInheritanceChain(ir.Class _class)
{
	ir.Class[] reverseClasses;

	while (_class !is null) {
		reverseClasses ~= _class;
		_class = _class.parentClass;
	}

	auto outClasses = new ir.Class[reverseClasses.length];
	for (size_t i = reverseClasses.length - 1, j = 0; i < reverseClasses.length; --i, ++j) {
		auto rClass = reverseClasses[i];
		outClasses[j] = rClass;
	}

	return outClasses;
}

ir.Exp[] getTypeInfos(ir.Class[] classes)
{
	auto tinfos = new ir.Exp[classes.length];
	foreach (i, _class; classes) {
		tinfos[i] = buildTypeidSmart(_class.location, _class);
	}
	return tinfos;
}

void emitVtableVariable(LanguagePass lp, ir.Class _class)
{
	auto addrs = getClassMethodAddrOfs(lp, _class);
	auto tinfo = retrieveTypeInfo(lp, _class.myScope, _class.location);
	auto chain = getInheritanceChain(_class);
	auto tinfos = getTypeInfos(chain);
	auto tinfosArr = buildArrayLiteralSmart(_class.location, buildArrayTypeSmart(_class.location, tinfo), tinfos);

	auto assign = new ir.StructLiteral();
	assign.location = _class.location;
	assign.exps = tinfosArr ~ addrs;
	assign.type = copyTypeSmart(_class.location, _class.vtableStruct);

	_class.vtableVariable = buildVariableSmart(_class.location, _class.vtableStruct, ir.Variable.Storage.Global, "__vtable_instance");
	_class.vtableVariable.mangledName = "_V__Vtable_" ~ mangle(null, _class);
	_class.vtableVariable.assign = assign;
	_class.members.nodes ~= _class.vtableVariable;
	_class.myScope.addValue(_class.vtableVariable, _class.vtableVariable.name);
}

/**
 * Handle things like 'Object.val = 3;'.
 */
bool handleClassTypePostfixIfNeeded(LanguagePass lp, ir.Scope current, ir.Postfix exp, ir.Type referredType)
{
	auto expressionClass = cast(ir.Class) referredType;
	if (expressionClass is null) {
		return false;
	}

	auto _this = getThisVar(exp.location, lp, current);
	auto tr = cast(ir.TypeReference) _this.type;
	if (tr is null) return false;
	auto thisClass = cast(ir.Class) tr.type;
	if (thisClass is null) return false;

	if (!thisClass.isOrInheritsFrom(expressionClass)) {
		throw new CompilerError(exp.location, format("this is not an instance of '%s'", expressionClass.name));
	}

	exp.child = buildCastSmart(exp.child.location, expressionClass, buildExpReference(_this.location, _this, "this"));

	return true;
}
