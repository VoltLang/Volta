// Copyright © 2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.classresolver;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.interfaces;
import volt.errors;

import volt.token.location;

import volt.semantic.classify;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.util;
import volt.semantic.overload;
import volt.semantic.typeinfo;


void actualizeClass(LanguagePass lp, ir.Class c)
{
	createAggregateVar(lp, c);

	fillInParentIfNeeded(lp, c);

	if (!c.isObject) {
		lp.actualize(c.parentClass);
	}

	fillInClassLayoutIfNeeded(c, lp);

	c.isActualized = true;

	fileInAggregateVar(lp, c);
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
		throw makeExpectedContext(ident, null);
	}
	_class = _class.parentClass;
	assert(_class !is null);


	if (p.op == ir.Postfix.Op.Call) {
		return rewriteSuperCallIfNeeded(e, p, _scope, lp, _class);
	} else if (p.op == ir.Postfix.Op.Identifier) {
		return rewriteSuperIdentifierIfNeeded(e, p, _scope, lp, _class);
	} else {
		throw makeFailedLookup(p, "super");
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

	auto asFunction = getParentFunction(_scope);
	if (asFunction is null) {
		throw makeExpectedContext(p, asFunction);
	}
	asFunction.explicitCallToSuper = true;

	auto thisVar = getThisVar(p.location, lp, _scope);
	auto thisRef = buildExpReference(thisVar.location, thisVar, "this");

	auto fn = selectFunction(lp, _scope, _class.userConstructors, p.arguments, e.location);

	p.child = buildCreateDelegate(p.location, thisRef, buildExpReference(p.location, fn, fn.name));
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
		parent = lp.objectClass;
	} else {
		// Use surrounding scope, and not this unresolved class.
		parent = cast(ir.Class) lookupType(lp, c.myScope.parent, c.parent);
		if (parent is null) {
			throw makeExpected(c.parent, "class");
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

ir.Function generateDefaultConstructor(LanguagePass lp, ir.Scope current, ir.Class _class)
{
	auto fn = buildFunction(_class.location, _class.members, current, "this");
	fn.kind = ir.Function.Kind.Constructor;
	buildReturnStat(fn.location, fn._body);

	auto tr = buildTypeReference(_class.location, _class,  "__this");
	auto thisVar = new ir.Variable();
	thisVar.location = fn.location;
	thisVar.type = tr;
	thisVar.name = "this";
	thisVar.storage = ir.Variable.Storage.Function;
	thisVar.useBaseStorage = true;
	fn.thisHiddenParameter = thisVar;
	fn.type.hiddenParameter = true;

	return fn;
}

/// Get all the functions in an inheritance chain -- ignore overloading.
ir.Function[][] getClassMethods(LanguagePass lp, ir.Scope current, ir.Class _class)
{
	bool gatherConstructors = _class.userConstructors.length == 0;
	ir.Function[][] methods;
	if (_class.parentClass !is null) {
		methods ~= getClassMethods(lp, _class.parentClass.myScope, _class.parentClass);
	}
	methods.length++;
	foreach (node; _class.members.nodes) {
		auto asFunction = cast(ir.Function) node;
		if (asFunction is null) {
			continue;
		}

		lp.resolve(current, asFunction);

		if (asFunction.kind == ir.Function.Kind.Constructor) {
			if (gatherConstructors) {
				_class.userConstructors ~= asFunction;
			}
			continue;
		} else if (asFunction.kind == ir.Function.Kind.Destructor) {
			asFunction.isMarkedOverride = !_class.isObject;
		}

		methods[$-1] ~= asFunction;
	}

	if (_class.userConstructors.length == 0) {
		_class.userConstructors ~= generateDefaultConstructor(lp, current, _class);
	}

	return methods;
}

ir.Function[] getClassMethodFunctions(LanguagePass lp, ir.Class _class)
{
	ir.Function[][] methodss = getClassMethods(lp, _class.myScope, _class);

	size_t outIndex;
	ir.Function[] outMethods;
	foreach (ref methods; methodss) {
		bool noPriorMethods = false;
		if (outMethods.length > 0) {
			foreach (method; methods) {
				overrideFunctionsIfNeeded(lp, method, outMethods);
			}
		} else {
			noPriorMethods = true;
		}
		foreach (method; methods) {
			auto fns = getPotentialOverrideFunctions(methods, method);
			fns ~= method;
			if (fns.length > 0) {
				// Ensure that this function is the only overload possibility for itself in its own class.
				auto tmp = selectFunction(lp, fns, method.type.params, method.location);
			}

			if (noPriorMethods && method.isMarkedOverride) {
				throw makeMarkedOverrideDoesNotOverride(method, method);
			}
			if (method.isMarkedOverride) {
				continue;
			}
			outMethods ~= method;
			method.vtableIndex = cast(int)outIndex++;
		}
	}
	return outMethods;
}

/**
 * Returns all functions in functions that have the same name as considerFunction.
 */
ir.Function[] getPotentialOverrideFunctions(ir.Function[] functions, ir.Function considerFunction)
{
	ir.Function[] _out;
	foreach (fn; functions) {
		if (fn is considerFunction) {
			continue;
		}
		if (fn.name == considerFunction.name) {
			_out ~= fn;
		}
	}
	return _out;
}

/**
 * Replace an overriden function in parentSet with childFunction if appropriate.
 * Returns true if a function is replaced, false otherwise.
 */
bool overrideFunctionsIfNeeded(LanguagePass lp, ir.Function childFunction, ref ir.Function[] parentSet)
{
	auto toConsider = getPotentialOverrideFunctions(parentSet, childFunction);

	if (toConsider.length == 0) {
		if (childFunction.isMarkedOverride) {
			throw makeMarkedOverrideDoesNotOverride(childFunction, childFunction);
		}
		return false;
	}

	ir.Function selectedFunction = selectFunction(lp, toConsider, childFunction.type.params, childFunction.location);

	foreach (ref parentFunction; parentSet) {
		if (parentFunction is selectedFunction) {
			if (!childFunction.isMarkedOverride) {
				assert(childFunction !is parentFunction);
				throw makeNeedOverride(childFunction, parentFunction);
			}
			parentFunction = childFunction;
			return true;
		}
	}

	return false;
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
		if (method.isAbstract) {
			if (!_class.isAbstract) {
				throw makeAbstractHasToBeMember(_class, method);
			}
			addrs ~= buildConstantNull(_class.location, method.type);
			continue;
		}
		auto eref = buildExpReference(_class.location, method, method.name);
		eref.rawReference = true;
		addrs ~= eref;
	}
	return addrs;
}

ir.Struct getClassLayoutStruct(ir.Class _class, LanguagePass lp, ref ir.Struct vtableStruct)
{
	auto methodTypes = getClassMethodTypeVariables(lp, _class);
	auto tinfo = lp.typeInfoClass;
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
	auto tinfo = lp.typeInfoClass;
	auto chain = getInheritanceChain(_class);
	auto tinfos = getTypeInfos(chain);
	auto tinfosArr = buildArrayLiteralSmart(_class.location, buildArrayTypeSmart(_class.location, tinfo), tinfos);

	auto assign = new ir.StructLiteral();
	assign.location = _class.location;
	assign.exps = tinfosArr ~ addrs;
	assign.type = copyTypeSmart(_class.location, _class.vtableStruct);

	_class.vtableVariable = buildVariableSmart(_class.location, _class.vtableStruct, ir.Variable.Storage.Global, "__vtable_instance");
	_class.vtableVariable.mangledName = "_V__Vtable_" ~ mangle(_class);
	_class.vtableVariable.assign = assign;
	_class.members.nodes ~= _class.vtableVariable;
	_class.myScope.addValue(_class.vtableVariable, _class.vtableVariable.name);
}
