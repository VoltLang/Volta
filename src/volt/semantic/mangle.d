// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.mangle;

import std.conv;
import std.string;

import volt.errors;
import ir = volt.ir.ir;


/**
 * Mangle the name of type if not set mangled.
 */
void ensureMangled(ir.Type t)
{
	if (t.mangledName is null) {
		t.mangledName = mangle(t);
	}
}

/**
 * Mangle a type found in a given module.
 */
string mangle(ir.Type t)
{
	string mangledStr;
	mangleType(t, mangledStr);
	return mangledStr;
}

/**
 * Mangle a Variable found ina given module.
 *
 * @todo figure out what to do about names argument.
 */
string mangle(string[] names, ir.Variable v)
{
	string s = "Vv";
	mangleName(names, s);
	mangleString(v.name, s);
	mangleType(v.type, s);
	return s;
}

/**
 * Mangle a function.
 *
 * @todo figure out what to do about names argument.
 */
string mangle(string[] names, ir.Function fn)
{
	string s = "Vf";
	mangleName(names, s);
	mangleString(fn.name, s);
	mangleType(fn.type, s);
	return s;
}


private:


void mangleType(ir.Type t, ref string mangledString)
{
	switch (t.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto asPrim = cast(ir.PrimitiveType) t;
		assert(asPrim !is null);
		manglePrimitiveType(asPrim, mangledString);
		break;
	case ArrayType:
		auto asArray = cast(ir.ArrayType) t;
		assert(asArray !is null);
		mangledString ~= "a";
		mangleType(asArray.base, mangledString);
		break;
	case PointerType:
		auto asPointer = cast(ir.PointerType) t;
		assert(asPointer !is null);
		mangledString ~= "p";
		mangleType(asPointer.base, mangledString);
		break;
	case Struct:
		auto asStruct = cast(ir.Struct) t;
		assert(asStruct !is null);
		mangledString ~= "S";
		mangleScope(asStruct.myScope, mangledString);
		break;
	case Union:
		auto asUnion = cast(ir.Union) t;
		assert(asUnion !is null);
		mangledString ~= "U";
		mangleScope(asUnion.myScope, mangledString);
		break;
	case Class:
		auto asClass = cast(ir.Class) t;
		assert(asClass !is null);
		mangledString ~= "C";
		mangleScope(asClass.myScope, mangledString);
		break;
	case UserAttribute:
		auto asAttr = cast(ir.UserAttribute) t;
		assert(asAttr !is null);
		mangledString ~= "A";
		mangleScope(asAttr.myScope, mangledString);
		break;
	case Enum:
		auto asEnum = cast(ir.Enum) t;
		assert(asEnum !is null);
		mangledString ~= "E";
		mangleScope(asEnum.myScope, mangledString);
		mangleString(asEnum.name, mangledString);
		break;
	case Interface:
		auto asInterface = cast(ir._Interface) t;
		assert(asInterface !is null);
		mangledString ~= "I";
		mangleScope(asInterface.myScope, mangledString);
		mangleString(asInterface.name, mangledString);
		break;
	case TypeReference:
		auto asTypeRef = cast(ir.TypeReference) t;
		assert(asTypeRef !is null);
		assert(asTypeRef.type !is null);
		mangleType(asTypeRef.type, mangledString);
		break;
	case DelegateType:
		auto asDelegateType = cast(ir.DelegateType) t;
		assert(asDelegateType !is null);
		mangleDelegateType(asDelegateType, mangledString);
		break;
	case FunctionType:
		auto asFunctionType = cast(ir.FunctionType) t;
		assert(asFunctionType !is null);
		mangleFunctionType(asFunctionType, mangledString);
		break;
	case AAType:
		auto asAA = cast(ir.AAType) t;
		assert(asAA !is null);
		mangledString ~= "Aa";
		mangleType(asAA.key, mangledString);
		mangleType(asAA.value, mangledString);
		break;
	case StaticArrayType:
		auto asSA = cast(ir.StaticArrayType) t;
		assert(asSA !is null);
		mangledString ~= "at";
		mangledString ~= to!string(asSA.length);
		mangleType(asSA.base, mangledString);
		break;
	case StorageType:
		auto asST = cast(ir.StorageType) t;
		assert(asST !is null);
		final switch (asST.type) with (ir.StorageType.Kind) {
		case Auto: mangledString ~= "?"; break;  // the autos may be left in during -E.
		case Scope: mangledString ~= "e"; break;
		case Const: mangledString ~= "o"; break;
		case Immutable: mangledString ~= "m"; break;
		case Ref: mangledString ~= "r"; break;
		case Out: mangledString ~= "O"; break;
		}
		if (asST.base is null) {
			mangledString ~= "???NULLBASE???";
		} else {
			mangleType(asST.base, mangledString);
		}
		break;
	default:
		throw panicUnhandled(t, "type in mangler");
	}
}

void mangleFunctionType(ir.FunctionType fn, ref string mangledString)
{
	if (fn.hiddenParameter) {
		mangledString ~= "M";
	}
	mangledString ~= "F";
	mangleCallableType(fn, mangledString);
}

void mangleDelegateType(ir.DelegateType fn, ref string mangledString)
{
	mangledString ~= "D";
	mangleCallableType(fn, mangledString);
}

void mangleCallableType(ir.CallableType ct, ref string mangledString)
{
	mangleLinkage(ct.linkage, mangledString);
	foreach (i, param; ct.params) {
		mangleType(param, mangledString);
	}
	mangledString ~= "Z";  // This would be difference with variadics.
	mangleType(ct.ret, mangledString);
}
void manglePrimitiveType(ir.PrimitiveType t, ref string mangledString)
{
	final switch (t.type) with (ir.PrimitiveType.Kind) {
	case Bool:
		mangledString ~= "t";
		break;
	case Byte:
		mangledString ~= "b";
		break;
	case Char:
		mangledString ~= "c";
		break;
	case Wchar:
		mangledString ~= "w";
		break;
	case Dchar:
		mangledString ~= "d";
		break;
	case Double:
		mangledString ~= "fd";
		break;
	case Float:
		mangledString ~= "ff";
		break;
	case Int:
		mangledString ~= "i";
		break;
	case Long:
		mangledString ~= "l";
		break;
	case Real:
		mangledString ~= "fr";
		break;
	case Short:
		mangledString ~= "s";
		break;
	case Ubyte:
		mangledString ~= "ub";
		break;
	case Uint:
		mangledString ~= "ui";
		break;
	case Ulong:
		mangledString ~= "ul";
		break;
	case Ushort:
		mangledString ~= "us";
		break;
	case Void:
		mangledString ~= "v";
		break;
	}
}

void mangleScope(ir.Scope _scope, ref string mangledString)
{
	assert(_scope !is null);

	if (_scope.parent !is null) {
		mangleScope(_scope.parent, mangledString);
		mangleString(_scope.name, mangledString);
		return;
	}

	auto asModule = cast(ir.Module)_scope.node;
	if (asModule is null)
		throw panic(_scope.node.location, "top scope is not a module");

	foreach (id; asModule.name.identifiers) {
		mangleString(id.value, mangledString);
	}
}

void mangleLinkage(ir.Linkage l, ref string mangledString)
{
	final switch (l) with (ir.Linkage) {
	case Volt: mangledString ~= "v"; break;
	case C: mangledString ~= "c"; break;
	case CPlusPlus: mangledString ~= "C"; break;
	case D: mangledString ~= "d"; break;
	case Windows: mangledString ~= "W"; break;
	case Pascal: mangledString ~= "P"; break;
	case System:
		assert(false);  // I assume we'll have had a pass removing System by now.
	}
}

void mangleString(string s, ref string mangledString)
{
	mangledString ~= format("%s%s", s.length, s);
}

void mangleName(string[] names, ref string mangledString)
{
	foreach (name; names) {
		mangleString(name, mangledString);
	}
}
