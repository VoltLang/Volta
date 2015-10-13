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

import volt.semantic.util;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.classify;
import volt.semantic.typeinfo;
import volt.semantic.overload;


void actualizeInterface(LanguagePass lp, ir._Interface i)
{
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

	fileInAggregateVar(lp, c);
}

void rewriteSuper(LanguagePass lp, ir.Scope _scope, ir.IdentifierExp ident, ir.Postfix p)
{
	assert(ident.value == "super");
	assert(p is null || ident is p.child);

	if (p is null) {
		throw makeFailedLookup(p, "super");
	}

	ir.Scope dummyScope;
	ir.Class _class;
	if (!getFirstClass(_scope, dummyScope, _class)) {
		throw makeExpectedContext(ident, null);
	}
	_class = _class.parentClass;
	assert(_class !is null);

	if (p.op == ir.Postfix.Op.Call) {
		return rewriteSuperCall(lp, _scope, ident, p, _class);
	} else if (p.op == ir.Postfix.Op.Identifier) {
		return rewriteSuperIdentifier(lp, _scope, ident, p, _class);
	} else {
		throw makeFailedLookup(p, "super");
	}
}

void rewriteSuperIdentifier(LanguagePass lp, ir.Scope _scope, ir.IdentifierExp ident, ir.Postfix p, ir.Class _class)
{
	assert(p.op == ir.Postfix.Op.Identifier);

	auto thisVar = getThisVar(ident.location, lp, _scope);
	p.child = buildCastSmart(ident.location, _class, buildExpReference(p.location, thisVar, "this"));
}

void rewriteSuperCall(LanguagePass lp, ir.Scope _scope, ir.IdentifierExp ident, ir.Postfix p, ir.Class _class)
{
	assert(p.op == ir.Postfix.Op.Call);

	auto asFunction = getParentFunction(_scope);
	if (asFunction is null) {
		throw makeExpectedContext(p, asFunction);
	}
	asFunction.explicitCallToSuper = true;

	auto thisVar = getThisVar(ident.location, lp, _scope);
	auto thisRef = buildExpReference(ident.location, thisVar, "this");

	auto set = buildSet(ident.location, _class.userConstructors);
	auto setRef = buildExpReference(ident.location, set, "super");
	p.child = buildCreateDelegate(ident.location, thisRef, setRef);
}


/*
 *
 * Internal functions.
 *
 */

/**
 * Fills in _Interface.layoutStruct.
 */
void fillInInterfaceLayoutIfNeeded(LanguagePass lp, ir._Interface i)
{
	if (i.layoutStruct !is null) {
		return;
	}

	i.layoutStruct = getInterfaceLayoutStruct(i, lp);
}

/**
 * Fills in Class.layoutStruct and Class.vtableStruct.
 */
void fillInClassLayoutIfNeeded(LanguagePass lp, ir.Class c)
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
	if (c.isObject || c.parentClass !is null) {
		return;
	}

	ir.Class parent;

	void fillNullParent() {
		c.parent = buildQualifiedName(c.location, ["object", "Object"]);
		parent = lp.objectClass;
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

ir.Variable[] getClassFields(LanguagePass lp, ir.Class _class, size_t offset)
{
	ir.Variable[] fields;
	if (_class.parentClass !is null) {
		fields ~= getClassFields(lp, _class.parentClass, offset);
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
		offset += size(lp, asVar);
		fields ~= copyVariableSmart(asVar.location, asVar);
	}
	assert(_class.interfaces.length == _class.parentInterfaces.length);
	void addOffset(ir._Interface iface)
	{
		_class.interfaceOffsets ~= offset;
		offset += size(lp, buildSizeT(_class.location, lp));
		auto var = buildVariableSmart(_class.location, buildPtrSmart(_class.location, iface.layoutStruct), ir.Variable.Storage.Field, mangle(iface));
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

ir.Function[] getInterfaceMethods(LanguagePass lp, ir._Interface iface)
{
	ir.Function[] functions;
	foreach (node; iface.members.nodes) {
		auto asFunction =  cast(ir.Function) node;
		if (asFunction is null) {
			continue;
		}
		lp.resolve(iface.myScope, asFunction);
		functions ~= asFunction;
	}
	assert(iface.interfaces.length == iface.parentInterfaces.length);
	foreach (piface; iface.parentInterfaces) {
		functions ~= getInterfaceMethods(lp, piface);
	}
	return functions;
}

ir.Function[] getClassMethodFunctions(LanguagePass lp, ir.Class _class)
{
	ir.Function[][] methodss = getClassMethods(lp, _class.myScope, _class);

	ir.Function[] ifaceMethods;
	foreach (iface; _class.parentInterfaces) {
		ifaceMethods ~= getInterfaceFunctions(lp, iface);
	}
	foreach (method; methodss[$-1]) {
		auto fns = getPotentialOverrideFunctions(ifaceMethods, method);
		version (Volt) {
			ir.Type[] params = new ir.Type[](method.type.params);
		} else {
			ir.Type[] params = method.type.params.dup;
		}
		if (fns.length == 0) {
			continue;
		}
		auto fn = selectFunction(lp, fns, params, method.location, DoNotThrow);
		if (fn is null) {
			continue;
		}
		if (!method.isMarkedOverride) {
			throw makeNeedOverride(method, fn);
		} else if (method.isMarkedOverride) {
			method.isOverridingInterface = true;
		}
	}

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
				auto tmp = selectFunction(lp, fns, params, method.location);
			}

			if (noPriorMethods && method.isMarkedOverride) {
				throw makeMarkedOverrideDoesNotOverride(method, method);
			}
			if (method.isMarkedOverride && !method.isOverridingInterface) {
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
		if (childFunction.isMarkedOverride && !childFunction.isOverridingInterface) {
			throw makeMarkedOverrideDoesNotOverride(childFunction, childFunction);
		}
		return false;
	}

	ir.Function selectedFunction = selectFunction(lp, toConsider, childFunction.type.params, childFunction.location, DoNotThrow);
	if (selectedFunction is null) {
		return false;
	}

	foreach (ref parentFunction; parentSet) {
		if (parentFunction is selectedFunction) {
			if (!childFunction.isMarkedOverride) {
				assert(childFunction !is parentFunction);
				throw makeNeedOverride(childFunction, parentFunction);
			}
			if (parentFunction.type.isProperty && !childFunction.type.isProperty) {
				throw makeOverriddenNeedsProperty(childFunction);
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

ir.Struct getInterfaceLayoutStruct(ir._Interface iface, LanguagePass lp)
{
	auto l = iface.location;
	ir.Variable[] fields;
	fields ~= buildVariableSmart(l, buildSizeT(l, lp), ir.Variable.Storage.Field, "__offset");
	auto methods = getInterfaceMethods(lp, iface);
	foreach (method; methods) {
		fields ~= buildVariableSmart(l, copyTypeSmart(l, method.type), ir.Variable.Storage.Field, mangle(null, method));
	}
	auto layoutStruct = buildStruct(l, iface.members, iface.myScope, "__ifaceVtable", fields);
	layoutStruct.loweredNode = iface;
	return layoutStruct;
}

ir.Struct getClassLayoutStruct(ir.Class _class, LanguagePass lp, ref ir.Struct vtableStruct)
{
	auto methodTypes = getClassMethodTypeVariables(lp, _class);
	auto tinfo = lp.typeInfoClass;
	auto tinfos = buildVariableSmart(_class.location, buildArrayTypeSmart(_class.location, tinfo), ir.Variable.Storage.Field, "tinfos");

	vtableStruct = buildStruct(_class.location, _class.members, _class.myScope, "__Vtable", tinfos ~ methodTypes);
	auto vtableVar = buildVariableSmart(_class.location, buildPtrSmart(_class.location, vtableStruct), ir.Variable.Storage.Field, "__vtable");

	auto fields = getClassFields(lp, _class, /* Account for the vtable: */ size(lp, buildSizeT(_class.location, lp)));
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
		tinfos[i] = buildTypeidSmart(_class.location, _class);
	}
	return tinfos;
}

/// For a given interface, return every function that needs to be implemented by an implementor.
ir.Function[] getInterfaceFunctions(LanguagePass lp, ir._Interface iface)
{
	assert(iface.parentInterfaces.length == iface.interfaces.length);
	ir.Function[] fns;
	foreach (node; iface.members.nodes) {
		auto fn = cast(ir.Function) node;
		if (fn is null) {
			continue;
		}
		fns ~= fn;
	}
	foreach (piface; iface.parentInterfaces) {
		fns ~= getInterfaceFunctions(lp, piface);
	}
	return fns;
}

/// Get a struct literal with an implementation of an interface from a given class.
ir.Exp getInterfaceStructAssign(LanguagePass lp, ir.Class _class, ir.Scope _scope, ir._Interface iface, size_t ifaceIndex)
{
	assert(iface.layoutStruct !is null);
	auto l = _class.location;
	ir.Exp[] exps;
	exps ~= buildConstantSizeT(l, lp, _class.interfaceOffsets[ifaceIndex]);
	auto fns = getInterfaceFunctions(lp, iface);

	foreach (fn; fns) {
		auto store = lookupAsThisScope(lp, _scope, l, fn.name);
		if (store is null || !containsMatchingFunction(store.functions, fn)) {
			throw makeDoesNotImplement(l, _class, iface, fn);
		}
		foreach (sfn; store.functions) {
			lp.resolve(_scope, sfn);
			if (mangle(null, sfn) != mangle(null, fn)) {
				continue;
			}
			auto eref = buildExpReference(l, sfn, mangle(null, sfn));
			eref.rawReference = true;
			exps ~= eref;
		}
	}
	return buildStructLiteralSmart(l, iface.layoutStruct, exps);
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

	auto l = _class.location;
	_class.initVariable = buildVariableSmart(
		l, _class.layoutStruct, ir.Variable.Storage.Global, "__cinit");
	_class.initVariable.mangledName = "_V__cinit_" ~ _class.mangledName;
	_class.initVariable.isResolved = true;

	ir.Exp[] exps;
	exps ~= buildAddrOf(l, _class.vtableVariable, _class.vtableVariable.name);

	ir.Variable[] ifaceVars;
	auto classes = getInheritanceChain(_class);
	foreach (c; classes) {
		ifaceVars ~= c.ifaceVariables;
	}
	size_t ifaceIndex;

	foreach (i, node; _class.layoutStruct.members.nodes[1 .. $]) {
		auto var = cast(ir.Variable) node;
		if (var is null) {
			throw panic(l, "expected variable in layout struct");
		}
		if (fromInterface(var.type)) {
			auto iv = _class.ifaceVariables[ifaceIndex++];
			exps ~= buildAddrOf(l, iv, iv.name);
			continue;
		}
		exps ~= getDefaultInit(l, lp, _class.myScope, var.type);
	}

	_class.initVariable.assign = buildStructLiteralSmart(l, _class.layoutStruct, exps);
	_class.members.nodes ~= _class.initVariable;
	_class.myScope.addValue(_class.initVariable, _class.initVariable.name);
}

void emitVtableVariable(LanguagePass lp, ir.Class _class)
{
	auto l = _class.location;
	auto addrs = getClassMethodAddrOfs(lp, _class);
	auto tinfo = lp.typeInfoClass;
	auto classes = getInheritanceChain(_class);
	auto tinfos = getTypeInfos(classes);
	auto tinfosArr = buildArrayLiteralSmart(l, buildArrayTypeSmart(l, tinfo), tinfos);

	assert(_class.interfaces.length == _class.parentInterfaces.length);
	void addInterfaceInstance(ir._Interface iface, ir.Class fromParent, size_t i)
	{
		auto var = buildVariableSmart(l, iface.layoutStruct, ir.Variable.Storage.Global, format("__iface%s_instance", mangle(iface)));
		var.mangledName =  "_V__Interface_" ~ _class.mangledName ~ "_" ~ mangle(iface);
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

	auto assign = new ir.StructLiteral();
	assign.location = l;
	assign.exps = tinfosArr ~ addrs;
	assign.type = copyTypeSmart(l, _class.vtableStruct);

	_class.vtableVariable = buildVariableSmart(l, _class.vtableStruct, ir.Variable.Storage.Global, "__vtable_instance");
	_class.vtableVariable.isResolved = true;
	_class.vtableVariable.mangledName = "_V__Vtable_" ~ mangle(_class);
	_class.vtableVariable.assign = assign;
	_class.members.nodes ~= _class.vtableVariable;
	_class.myScope.addValue(_class.vtableVariable, _class.vtableVariable.name);

	buildInstanceVariable(lp, _class);
}
