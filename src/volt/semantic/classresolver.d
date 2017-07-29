// Copyright © 2013, Bernard Helyer.  All rights reserved.
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.classresolver;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volt.token.location;

import volt.util.sinks;

import volt.semantic.util;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.context : Context;
import volt.semantic.classify;
import volt.semantic.typeinfo;
import volt.semantic.overload;


void actualizeInterface(LanguagePass lp, ir._Interface i)
{
	createAggregateVar(lp, i);

	foreach (childI; i.interfaces) {
		auto iface = cast(ir._Interface) lookupType(lp, i.myScope.parent, childI);
		if (iface is null) {
			throw makeExpected(childI, "interface");
		}
		lp.actualize(iface);
		i.parentInterfaces ~= iface;
	}
	fillInInterfaceLayoutIfNeeded(lp, i);
	i.isActualized = true;

	fillInAggregateVar(lp, i);
}

void actualizeClass(LanguagePass lp, ir.Class c)
{
	createAggregateVar(lp, c);

	fillInParentIfNeeded(lp, c);

	if (!c.isObject) {
		lp.actualize(c.parentClass);
	}

	fillInInterfacesIfNeeded(lp, c);
	fillInClassLayoutIfNeeded(lp, c);

	c.isActualized = true;

	fillInAggregateVar(lp, c);
}

ir.Type rewriteThis(Context ctx, ref ir.Exp e, ir.IdentifierExp ident, bool isCall)
{
	assert(ident !is null);
	assert(ident.value == "this");

	ir.Variable thisVar;
	auto thisRef = getThisReferenceNotNull(ident, ctx, thisVar);
	assert(thisVar !is null);

	if (isCall) {
		return rewriteThisCall(ctx, e, ident, thisVar, thisRef);
	}

	// The simple default.
	e = thisRef;
	return thisVar.type;
}

ir.Type rewriteThisCall(Context ctx, ref ir.Exp e, ir.IdentifierExp ident,
                     ir.Variable thisVar, ir.Exp thisRef)
{
	auto type = realType(thisVar.type);
	auto _class = cast(ir.Class) type;
	if (_class is null) {
		throw makeExpected(ident.loc, "class");
	}

	auto set = buildSet(ident.loc, _class.userConstructors);
	auto setRef = buildExpReference(ident.loc, set, "this");
	auto asRef = cast(ir.ExpReference)thisRef;
	panicAssert(thisRef, asRef !is null);
	asRef.isSuperOrThisCall = true;
	e = buildCreateDelegate(ident.loc, thisRef, setRef);

	return buildVoid(e.loc);
}

ir.Type rewriteSuper(Context ctx, ref ir.Exp e, ir.IdentifierExp ident,
                  bool isCall, bool isIdentifier)
{
	assert(ident !is null);
	assert(ident.value == "super");

	if (!isCall && !isIdentifier) {
		throw makeExpected(ident.loc, "call or identifier postfix");
	}

	ir.Scope dummyScope;
	ir.Class _class;
	if (!getFirstClass(ctx.current, dummyScope, _class)) {
		throw makeExpectedContext(ident, null);
	}
	// TODO check for nested function, and dissallow.
	// if (<check for nested function>) {
	// 	throw makeNoSuperInNested(ident);
	// }

	// This is super, get the parent class.
	_class = _class.parentClass;
	assert(_class !is null);

	if (isCall) {
		return rewriteSuperCall(ctx, e, _class);
	} else if (isIdentifier) {
		return rewriteSuperIdentifier(e, _class);
	} else {
		throw panic(e, "super");
	}
}

ir.Type rewriteSuperIdentifier(ref ir.Exp e, ir.Class _class)
{
	// No better way of doing this. :-(
	// Also assumes that the class has a valid scope.
	auto store = _class.myScope.parent.getStore(_class.name);
	assert(store !is null);
	assert(store.node is _class);

	e = buildStoreExp(e.loc, store);

	return _class;
}

ir.Type rewriteSuperCall(Context ctx, ref ir.Exp e, ir.Class _class)
{
	auto thisVar = getThisVarNotNull(e, ctx);
	auto thisRef = buildExpReference(e.loc, thisVar, "this");
	thisRef.isSuperOrThisCall = true;

	auto set = buildSet(e.loc, _class.userConstructors);
	auto setRef = buildExpReference(e.loc, set, "super");
	e = buildCreateDelegate(e.loc, thisRef, setRef);

	return buildVoid(e.loc);
}


/*
 *
 * Internal functions.
 *
 */

/*!
 * Fills in _Interface.layoutStruct.
 */
void fillInInterfaceLayoutIfNeeded(LanguagePass lp, ir._Interface i)
{
	if (i.layoutStruct !is null) {
		return;
	}

	i.layoutStruct = getInterfaceLayoutStruct(i, lp);
}

/*!
 * Fills in Class.layoutStruct and Class.vtableStruct.
 */
void fillInClassLayoutIfNeeded(LanguagePass lp, ir.Class c)
{
	if (c.layoutStruct !is null) {
		return;
	}

	c.layoutStruct = getClassLayoutStruct(c, lp);
	emitVtableVariable(lp, c);
}

void fillInParentIfNeeded(LanguagePass lp, ir.Class c)
{
	if (c.isObject || c.parentClass !is null) {
		return;
	}

	ir.Class parent;

	void fillNullParent() {
		c.parent = buildQualifiedName(c.loc, ["core", "object", "Object"]);
		parent = lp.objObject;
	}

	if (c.parent is null) {
		fillNullParent();
	} else {
		// Use surrounding scope, and not this unresolved class.
		auto ptype = lookupType(lp, c.myScope.parent, c.parent);
		auto iface = cast(ir._Interface) ptype;
		if (iface !is null) {
			// If there's only one parent listed, the parser puts the interface in the parent slot.
			c.interfaces ~= c.parent;
			fillNullParent();
		} else {
			parent = cast(ir.Class) ptype;
			if (parent is null) {
				throw makeExpected(c.parent, "class");
			}
			if (parent.isFinal) {
				throw makeSubclassFinal(c, parent);
			}
		}
	}

	c.parentClass = parent;
}

void fillInInterfacesIfNeeded(LanguagePass lp, ir.Class c)
{
	foreach (ifaceName; c.interfaces) {
		auto iface = cast(ir._Interface) lookupType(lp, c.myScope.parent, ifaceName);
		if (iface is null) {
			throw makeExpected(ifaceName, "interface");
		}
		lp.actualize(iface);
		c.parentInterfaces ~= iface;
	}
}

ir.Variable[] getClassFields(LanguagePass lp, ir.Class _class, ref size_t offset)
{
	void addSize(ir.Type n)
	{
		auto a = alignment(lp.target, n);
		auto sz = size(lp.target, n);

		offset = calcAlignment(a, offset) + sz;
	}

	ir.Variable[] fields;
	if (_class.parentClass !is null) {
		fields ~= getClassFields(lp, _class.parentClass, offset);
	} else {
		offset = size(lp.target, buildSizeT(_class.loc, lp.target));  // Account for vtable.
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
		addSize(asVar.type);
		fields ~= copyVariableSmart(asVar.loc, asVar);
	}
	assert(_class.interfaces.length == _class.parentInterfaces.length);
	void addOffset(ir._Interface iface)
	{
		auto t = buildSizeT(_class.loc, lp.target);
		offset = calcAlignment(lp.target, t, offset);
		_class.interfaceOffsets ~= offset;
		addSize(t);
		auto var = buildVariableSmart(_class.loc, buildPtrSmart(_class.loc, iface.layoutStruct), ir.Variable.Storage.Field, mangle(iface));

		fields ~= var;
		assert(iface.interfaces.length == iface.parentInterfaces.length);
		foreach (piface; iface.parentInterfaces) {
			addOffset(piface);
		}
	}

	foreach (iface; _class.parentInterfaces) {
		addOffset(iface);
	}
	return fields;
}

ir.Function generateDefaultConstructor(LanguagePass lp, ir.Scope current, ir.Class _class)
{
	auto func = buildFunction(_class.loc, _class.members, current, "__ctor");
	func.kind = ir.Function.Kind.Constructor;

	buildReturnStat(func.loc, func._body);

	auto tr = buildTypeReference(_class.loc, _class,  "__this");
	auto thisVar = new ir.Variable();
	thisVar.loc = func.loc;
	thisVar.type = tr;
	thisVar.name = "this";
	thisVar.storage = ir.Variable.Storage.Function;
	thisVar.useBaseStorage = true;
	func.thisHiddenParameter = thisVar;
	func.type.hiddenParameter = true;

	return func;
}

//! Get all the functions in an inheritance chain -- ignore overloading.
ir.Function[][] getClassMethods(LanguagePass lp, ir.Scope current, ir.Class _class)
{
	if (_class.methodsCache.length != 0) {
		return _class.methodsCache;
	}

	FunctionArraySink methods;
	appendClassMethods(lp, current, _class, /*ref*/ methods);
	_class.methodsCache = methods.toArray();
	return _class.methodsCache;
}

void appendClassMethods(LanguagePass lp, ir.Scope current, ir.Class _class, ref FunctionArraySink methods)
{
	if (_class.methodsCache.length != 0) {
		methods.append(_class.methodsCache);
		return;
	}

	bool gatherConstructors = _class.userConstructors.length == 0;
	if (_class.parentClass !is null) {
		appendClassMethods(lp, _class.parentClass.myScope, _class.parentClass, /*ref*/ methods);
	}

	FunctionSink fns;
	foreach (node; _class.members.nodes) {
		auto _t = cast(ir.Type)node;
		if (_t !is null) {
			resolveChildStructsAndUnions(lp, realType(_t, false));
		}
		auto asFunction = cast(ir.Function) node;
		if (asFunction is null) {
			continue;
		}

		lp.resolve(current, asFunction);

		if (_class.isFinal) {
			asFunction.isFinal = true;
		}

		if (asFunction.kind == ir.Function.Kind.Constructor) {
			if (gatherConstructors) {
				_class.userConstructors ~= asFunction;
			}
			continue;
		} else if (asFunction.kind == ir.Function.Kind.Destructor) {
			asFunction.isMarkedOverride = !_class.isObject;
		}

		fns.sink(asFunction);
	}

	if (_class.userConstructors.length == 0) {
		_class.userConstructors ~= generateDefaultConstructor(lp, current, _class);
	}

	methods.sink(fns.toArray());
}

void appendInterfaceMethods(LanguagePass lp, ir._Interface iface, ref FunctionSink functions)
{
	foreach (node; iface.members.nodes) {
		auto asFunction =  cast(ir.Function) node;
		if (asFunction is null) {
			continue;
		}
		lp.resolve(iface.myScope, asFunction);
		functions.sink(asFunction);
	}
	assert(iface.interfaces.length == iface.parentInterfaces.length);
	foreach (piface; iface.parentInterfaces) {
		appendInterfaceMethods(lp, piface, /*ref*/ functions);
	}
}

void appendClassMethodFunctions(LanguagePass lp, ir.Class _class, ref FunctionSink outMethods)
{
	ir.Function[][] methodss = getClassMethods(lp, _class.myScope, _class);

	FunctionSink ifaceMethods;
	foreach (iface; _class.parentInterfaces) {
		appendInterfaceFunctions(lp, iface, /*ref*/ ifaceMethods);
	}
	foreach (method; methodss[$-1]) {
		FunctionSink fnsink;
		appendPotentialOverrideFunctions(ifaceMethods, method, /*ref*/ fnsink);
		version (Volt) {
			ir.Type[] params = new ir.Type[](method.type.params);
		} else {
			ir.Type[] params = method.type.params.dup;
		}
		if (fnsink.length == 0) {
			continue;
		}
		auto func = selectFunction(/*ref*/ fnsink, params, method.loc, DoNotThrow);
		if (func is null) {
			continue;
		}
		if (!method.isMarkedOverride) {
			throw makeNeedOverride(method, func);
		} else if (method.isMarkedOverride) {
			method.isOverridingInterface = true;
		}
	}

	size_t offset = 2;  // ClassInfo array length and pointer takes up the first two slots.
	size_t outIndex;
	foreach (methods; methodss) {
		bool noPriorMethods = false;
		if (outMethods.length > 0) {
			foreach (method; methods) {
				overrideFunctionsIfNeeded(lp, method, outMethods);
			}
		} else {
			noPriorMethods = true;
		}
		foreach (method; methods) {
			FunctionSink fnsink;
			appendPotentialOverrideFunctions(methods, method, /*ref*/ fnsink);
			fnsink.sink(method);
			if (fnsink.length > 0) {
				// Ensure that this function is the only overload possibility for itself in its own class.
				version (Volt) {
					ir.Type[] params = new ir.Type[](method.type.params);
				} else {
					ir.Type[] params = method.type.params.dup;
				}
				if (method.type.homogenousVariadic) {
					auto atype = cast(ir.ArrayType) params[$ - 1];
					panicAssert(method, atype !is null);
					params[$ - 1] = atype.base;
				}
				auto tmp = selectFunction(/*ref*/ fnsink, params, method.loc);
			}

			if (noPriorMethods && method.isMarkedOverride) {
				throw makeMarkedOverrideDoesNotOverride(method, method);
			}
			if (method.isMarkedOverride && !method.isOverridingInterface) {
				continue;
			}
			outMethods.sink(method);
			method.vtableIndex = cast(int)(outIndex++ + offset);
		}
	}
}

/*!
 * Returns all functions in functions that have the same name as considerFunction.
 */
void appendPotentialOverrideFunctions(ir.Function[] functions, ir.Function considerFunction, ref FunctionSink _out)
{
	foreach (func; functions) {
		appendPotentialOverrideFunctions(func, considerFunction, /*ref*/ _out);
	}
}

void appendPotentialOverrideFunctions(ref FunctionSink functions, ir.Function considerFunction, ref FunctionSink _out)
{
	for (size_t i; i < functions.length; i++) {
		auto func = functions.get(i);
		appendPotentialOverrideFunctions(func, considerFunction, /*ref*/ _out);
	}
}

void appendPotentialOverrideFunctions(ir.Function func, ir.Function considerFunction, ref FunctionSink _out)
{
	if (func is considerFunction) {
		return;
	}

	if (func.name == considerFunction.name) {
		if (func.access != considerFunction.access) {
			throw makeOverriddenFunctionsAccessMismatch(func, considerFunction);
		}
		_out.sink(func);
	}
}

/*!
 * Replace an overriden function in parentSet with childFunction if appropriate.
 * Returns true if a function is replaced, false otherwise.
 */
bool overrideFunctionsIfNeeded(LanguagePass lp, ir.Function childFunction, ref FunctionSink parentSet)
{
	FunctionSink toConsiderSink;
	appendPotentialOverrideFunctions(parentSet, childFunction, /*ref*/ toConsiderSink);

	if (toConsiderSink.length == 0) {
		if (childFunction.isMarkedOverride && !childFunction.isOverridingInterface) {
			throw makeMarkedOverrideDoesNotOverride(childFunction, childFunction);
		}
		return false;
	}

	ir.Function selectedFunction = selectFunction(/*ref*/ toConsiderSink, childFunction.type.params, childFunction.loc, DoNotThrow);
	if (selectedFunction is null) {
		if (childFunction.isMarkedOverride) {
			throw makeMarkedOverrideDoesNotOverride(childFunction, childFunction);
		}
		return false;
	}

	for (size_t i = 0; i < parentSet.length; ++i) {
		auto parentFunction = parentSet.get(i);
		if (parentFunction is selectedFunction) {
			if (!childFunction.isMarkedOverride) {
				assert(childFunction !is parentFunction);
				throw makeNeedOverride(childFunction, parentFunction);
			}
			if (parentFunction.isFinal) {
				throw makeOverridingFinal(childFunction);
			}
			if (parentFunction.type.isProperty && !childFunction.type.isProperty) {
				throw makeOverriddenNeedsProperty(childFunction);
			}
			childFunction.vtableIndex = parentFunction.vtableIndex;
			parentSet.set(i, childFunction);
			return true;
		}
	}

	return false;
}

ir.Variable[] getClassMethodTypeVariables(LanguagePass lp, ir.Class _class)
{
	FunctionSink methods;
	appendClassMethodFunctions(lp, _class, /*ref*/ methods);

	ir.Variable[] typeVars;
	for (size_t i = 0; i < methods.length; ++i) {
		auto method = methods.get(i);
		typeVars ~= buildVariableSmart(method.loc, method.type, ir.Variable.Storage.Field, format("_%s", i));
	}
	return typeVars;
}

ir.Struct getInterfaceLayoutStruct(ir._Interface iface, LanguagePass lp)
{
	auto loc = iface.loc;
	FunctionSink methods;
	appendInterfaceMethods(lp, iface, /*ref*/ methods);
	auto fields = new ir.Variable[](methods.length + 1);
	fields[0] = buildVariableSmart(loc, buildSizeT(loc, lp.target), ir.Variable.Storage.Field, "__offset");
	for (size_t i = 0; i < methods.length; ++i) {
		auto method = methods.get(i);
		fields[i+1] = buildVariableSmart(loc, copyTypeSmart(loc, method.type), ir.Variable.Storage.Field, mangle(null, method));
	}
	auto layoutStruct = buildStruct(loc, iface.members, iface.myScope, "__ifaceVtable", fields);
	layoutStruct.loweredNode = iface;
	// This should be resolved now.
	lp.resolveNamed(layoutStruct);
	return layoutStruct;
}

ir.Struct getClassLayoutStruct(ir.Class _class, LanguagePass lp)
{
	auto methodTypes = getClassMethodTypeVariables(lp, _class);
	auto tinfo = lp.tiClassInfo;
	auto tinfos = buildVariableSmart(_class.loc, buildArrayTypeSmart(_class.loc, tinfo), ir.Variable.Storage.Field, "tinfos");

	auto vtableVar = buildVariableSmart(_class.loc, buildPtrSmart(_class.loc, buildVoidPtr(_class.loc)), ir.Variable.Storage.Field, "__vtable");

	size_t dummy;
	auto fields = getClassFields(lp, _class, dummy);
	fields = vtableVar ~ fields;

	auto layoutStruct = buildStruct(_class.loc, _class.members, _class.myScope, "__layoutStruct", fields);
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

	auto outClasses = new ir.Class[](reverseClasses.length);
	for (size_t i = reverseClasses.length - 1, j = 0; i < reverseClasses.length; --i, ++j) {
		auto rClass = reverseClasses[i];
		outClasses[j] = rClass;
	}

	return outClasses;
}

ir.Exp[] getTypeInfos(ir.Class[] classes)
{
	auto tinfos = new ir.Exp[](classes.length);
	foreach (i, _class; classes) {
		tinfos[i] = buildCastToVoidPtr(_class.loc, buildTypeidSmart(_class.loc, _class));
	}
	return tinfos;
}

//! For a given interface, return every function that needs to be implemented by an implementor.
void appendInterfaceFunctions(LanguagePass lp, ir._Interface iface, ref FunctionSink _out)
{
	assert(iface.parentInterfaces.length == iface.interfaces.length);
	foreach (node; iface.members.nodes) {
		auto func = cast(ir.Function) node;
		if (func is null) {
			continue;
		}
		_out.sink(func);
	}
	foreach (piface; iface.parentInterfaces) {
		appendInterfaceFunctions(lp, piface, /*ref*/ _out);
	}
}

//! Get a struct literal with an implementation of an interface from a given class.
ir.Exp getInterfaceStructAssign(LanguagePass lp, ir.Class _class, ir.Scope _scope, ir._Interface iface, size_t ifaceIndex)
{
	assert(iface.layoutStruct !is null);
	auto loc = _class.loc;
	ir.Exp[] exps;
	exps ~= buildConstantSizeT(loc, lp.target, _class.interfaceOffsets[ifaceIndex]);
	FunctionSink fns;
	appendInterfaceFunctions(lp, iface, /*ref*/ fns);

	for (size_t i = 0; i < fns.length; ++i) {
		auto func = fns.get(i);
		auto store = lookupAsThisScope(lp, _scope, loc, func.name, _class.myScope);
		if (store is null || !containsMatchingFunction(store.functions, func)) {
			throw makeDoesNotImplement(loc, _class, iface, func);
		}
		foreach (sfn; store.functions) {
			lp.resolve(_scope, sfn);
			if (mangle(null, sfn) != mangle(null, func)) {
				continue;
			}
			auto eref = buildExpReference(loc, sfn, mangle(null, sfn));
			eref.rawReference = true;
			exps ~= eref;
		}
	}
	return buildStructLiteralSmart(loc, iface.layoutStruct, exps);
}

void buildInstanceVariable(LanguagePass lp, ir.Class _class)
{
	bool fromInterface(ir.Type t) {
		auto ptr = cast(ir.PointerType) t;
		if (ptr !is null) {
			auto tr = cast(ir.TypeReference) ptr.base;
			if (tr !is null) {
				auto str = cast(ir.Struct) tr.type;
				if (str !is null && str.loweredNode !is null) {
					return (cast(ir._Interface) str.loweredNode) !is null;
				}
			}
		}
		return false;
	}

	auto loc = _class.loc;
	_class.initVariable = buildVariableSmart(
		loc, _class.layoutStruct, ir.Variable.Storage.Global, "__cinit");
	_class.initVariable.mangledName = format("_V__cinit_%s", _class.mangledName);
	_class.initVariable.isResolved = true;

	ir.Exp[] exps;
	exps ~= buildCastSmart(loc, buildPtr(loc, buildVoidPtr(loc)),
		buildAddrOf(loc,
		buildExpReference(loc, _class.vtableVariable, _class.vtableVariable.name)));

	ir.Variable[] ifaceVars;
	auto classes = getInheritanceChain(_class);
	foreach (c; classes) {
		ifaceVars ~= c.ifaceVariables;
	}
	size_t ifaceIndex;

	foreach (i, node; _class.layoutStruct.members.nodes[1 .. $]) {
		auto var = cast(ir.Variable) node;
		if (var is null) {
			throw panic(loc, "expected variable in layout struct");
		}
		if (fromInterface(var.type)) {
			auto iv = _class.ifaceVariables[ifaceIndex++];
			exps ~= buildAddrOf(loc, iv, iv.name);
			continue;
		}
		exps ~= getDefaultInit(loc, lp, var.type);
	}

	_class.initVariable.assign = buildStructLiteralSmart(loc, _class.layoutStruct, exps);
	_class.members.nodes ~= _class.initVariable;
	_class.myScope.addValue(_class.initVariable, _class.initVariable.name);
}

void emitVtableVariable(LanguagePass lp, ir.Class _class)
{
	auto loc = _class.loc;
	auto tinfo = lp.tiClassInfo;
	auto classes = getInheritanceChain(_class);

	assert(_class.interfaces.length == _class.parentInterfaces.length);
	void addInterfaceInstance(ir._Interface iface, ir.Class fromParent, size_t i)
	{
		auto var = buildVariableSmart(loc, iface.layoutStruct, ir.Variable.Storage.Global, format("%s", mangle(iface)));
		var.mangledName =  format("_V__Interface_%s_%s", _class.mangledName, mangle(iface));
		var.assign = getInterfaceStructAssign(lp, fromParent, _class.myScope, iface, i);
		_class.members.nodes ~= var;
		_class.myScope.addValue(var, var.name);
		_class.ifaceVariables ~= var;
		assert(iface.interfaces.length == iface.parentInterfaces.length);
		foreach (j, piface; iface.parentInterfaces) {
			addInterfaceInstance(piface, fromParent, i + (j + 1));
		}
	}

	foreach (c; classes) {
		foreach (i, iface; c.parentInterfaces) {
			addInterfaceInstance(iface, c, i);
		}
	}

	auto tinfos = getTypeInfos(classes);
	_class.classinfoVariable = buildVariableSmart(loc, buildStaticArrayTypeSmart(loc, tinfos.length, buildVoidPtr(loc)), ir.Variable.Storage.Global, "__classinfo_instance");
	_class.classinfoVariable.isResolved = true;
	_class.classinfoVariable.mangledName = format("_V__ClassInfos_%s", mangle(_class));
	_class.classinfoVariable.assign = buildArrayLiteralSmart(loc, _class.classinfoVariable.type, tinfos);
	_class.members.nodes ~= _class.classinfoVariable;
	_class.myScope.addValue(_class.classinfoVariable, _class.classinfoVariable.name);

	FunctionSink methods;
	appendClassMethodFunctions(lp, _class, methods);
	for (size_t i = 0; i < methods.length; ++i) {
		auto method = methods.get(i);
		if (method.isAbstract) {
			if (!_class.isAbstract) {
				throw makeAbstractHasToBeMember(_class, method);
			}
		}
	}

	auto vtype = buildStaticArrayTypeSmart(loc, 2 + methods.length, buildVoidPtr(loc));
	_class.vtableVariable = buildVariableSmart(loc, vtype, ir.Variable.Storage.Global, "__vtable_instance");
	_class.vtableVariable.isResolved = true;
	_class.vtableVariable.mangledName = format("_V__Vtable_%s", mangle(_class));
	_class.vtableVariable.assign = buildBuildVtable(loc, vtype, _class, methods);
	_class.members.nodes ~= _class.vtableVariable;
	_class.myScope.addValue(_class.vtableVariable, _class.vtableVariable.name);

	buildInstanceVariable(lp, _class);
}
