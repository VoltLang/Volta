// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.mangle;

import std.conv;
import std.string;

import volt.exceptions;
import ir = volt.ir.ir;


/**
 * Mangle a type found in a given module.
 *
 * @todo remove names argument.
 */
string mangle(string[] names, ir.Type t)
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
	string s = "_V";
	mangleName(names, s);
	mangleString(v.name, s);
	mangleType(v.type, s);
	return s;
}

/**
 * Mangle a function.
 *
 * @todo remove names argument.
 */
string mangle(string[] names, ir.Function fn)
{
	string s = "_V";
	mangleScope(fn.myScope, s);
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
		mangledString ~= "A";
		mangleType(asArray.base, mangledString);
		break;
	case PointerType:
		auto asPointer = cast(ir.PointerType) t;
		assert(asPointer !is null);
		mangledString ~= "P";
		mangleType(asPointer.base, mangledString);
		break;
	case Struct:
		auto asStruct = cast(ir.Struct) t;
		assert(asStruct !is null);
		if (asStruct.loweredNode !is null) {
			auto asType = cast(ir.Type) asStruct.loweredNode;
			assert(asType !is null);
			mangleType(asType, mangledString);
		} else {
			mangledString ~= "S";
			mangleScope(asStruct.myScope, mangledString);
		}
		break;
	case Class:
		auto asClass = cast(ir.Class) t;
		assert(asClass !is null);
		mangledString ~= "C";
		mangleScope(asClass.myScope, mangledString);
		break;
	case Enum:
		auto asEnum = cast(ir.Enum) t;
		assert(asEnum !is null);
		mangledString ~= "E";
		/// @todo Add myScope field to enum.
		//mangleScope(asEnum.myScope, mangledString);
		mangleString(asEnum.name, mangledString);
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
		mangledString ~= "H";
		mangleType(asAA.key, mangledString);
		mangleType(asAA.value, mangledString);
		break;
	case StaticArrayType:
		auto asSA = cast(ir.StaticArrayType) t;
		assert(asSA !is null);
		mangledString ~= "G";
		mangledString ~= to!string(asSA.length);
		mangleType(asSA.base, mangledString);
		break;
	case StorageType:
		auto asST = cast(ir.StorageType) t;
		assert(asST !is null);
		mangleType(asST.base, mangledString);
		break;
	default:
		mangledString = "unknown" ~ to!string(t.nodeType);
		break;
	}
}

void mangleFunctionType(ir.FunctionType fn, ref string mangledString)
{
	mangleLinkage(fn.linkage, mangledString);
	if (fn.hiddenParameter) {
		mangledString ~= "M";
	}
	// !!! Attributes go here. !!!
	foreach (i, param; fn.params) {
		mangleType(param.type, mangledString);
	}
	mangledString ~= "Z";  // This would be difference with variadics.
	mangleType(fn.ret, mangledString);
}

void mangleDelegateType(ir.DelegateType fn, ref string mangledString)
{
	mangledString ~= "D";
	mangleLinkage(fn.linkage, mangledString);
	// !!! Attributes go here. !!!
	foreach (param; fn.params) {
		mangleType(param.type, mangledString);
	}
	mangledString ~= "Z";  // This would be difference with variadics.
	mangleType(fn.ret, mangledString);
}

void manglePrimitiveType(ir.PrimitiveType t, ref string mangledString)
{
	final switch (t.type) with (ir.PrimitiveType.Kind) {
	case Bool:
		mangledString ~= "b";
		break;
	case Byte:
		mangledString ~= "g";
		break;
	case Char:
		mangledString ~= "a";
		break;
	case Double:
		mangledString ~= "d";
		break;
	case Float:
		mangledString ~= "f";
		break;
	case Int:
		mangledString ~= "i";
		break;
	case Long:
		mangledString ~= "l";
		break;
	case Real:
		mangledString ~= "e";
		break;
	case Short:
		mangledString ~= "s";
		break;
	case Ubyte:
		mangledString ~= "h";
		break;
	case Uint:
		mangledString ~= "k";
		break;
	case Ulong:
		mangledString ~= "m";
		break;
	case Ushort:
		mangledString ~= "t";
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
		throw CompilerPanic(_scope.node.location, "top scope is not a module");

	foreach (id; asModule.name.identifiers) {
		mangleString(id.value, mangledString);
	}
}

void mangleLinkage(ir.Linkage l, ref string mangledString)
{
	final switch (l) with (ir.Linkage) {
	case Volt: mangledString ~= "Q"; break;
	case C: mangledString ~= "U"; break;
	case CPlusPlus: mangledString ~= "R"; break;
	case D: mangledString ~= "F"; break;
	case Windows: mangledString ~= "W"; break;
	case Pascal: mangledString ~= "V"; break;
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
