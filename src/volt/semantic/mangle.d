// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.mangle;

import std.conv;
import std.string;

import ir = volt.ir.ir;

/**
 * Mangle a type found in a given module.
 */
string mangle(string[] names, ir.Type t)
{
	string mangledStr = "_V";
	mangleBase(t, names, mangledStr);
	return mangledStr;
}

string mangle(string[] names, ir.Variable v)
{
	string s = mangle(names, v.type);
	mangleName(names, s);
	mangleString(v.name, s);
	return s;
}

string mangle(string[] names, ir.Function fn)
{
	string s = mangle(names, fn.type);
	mangleName(names, s);
	mangleString(fn.name, s);
	return s;
}

private:

void mangleBase(ir.Type t, string[] names, ref string mangledString)
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
		mangleBase(asArray.base, names, mangledString);
		break;
	case PointerType:
		auto asPointer = cast(ir.PointerType) t;
		assert(asPointer !is null);
		mangledString ~= "P";
		mangleBase(asPointer.base, names, mangledString);
		break;
	case Struct:
		auto asStruct = cast(ir.Struct) t;
		assert(asStruct !is null);
		if (asStruct.loweredNode !is null) {
			auto asType = cast(ir.Type) asStruct.loweredNode;
			assert(asType !is null);
			mangleBase(asType, names, mangledString);
		} else {
			mangledString ~= "S";
			mangleName(names ~ asStruct.name, mangledString);
		}
		break;
	case Class:
		auto asClass = cast(ir.Class) t;
		assert(asClass !is null);
		mangledString ~= "C";
		mangleName(names ~ asClass.name, mangledString);
		break;
	case Enum:
		auto asEnum = cast(ir.Enum) t;
		assert(asEnum !is null);
		mangledString ~= "E";
		mangleName(names ~ asEnum.name, mangledString);
		break;
	case TypeReference:
		auto asTypeRef = cast(ir.TypeReference) t;
		assert(asTypeRef !is null);
		assert(asTypeRef.type !is null);
		mangleBase(asTypeRef.type, names, mangledString);
		break;
	case DelegateType:
		auto asDelegateType = cast(ir.DelegateType) t;
		assert(asDelegateType !is null);
		mangleDelegateType(asDelegateType, names, mangledString);
		break;
	case FunctionType:
		auto asFunctionType = cast(ir.FunctionType) t;
		assert(asFunctionType !is null);
		mangleFunctionType(asFunctionType, names, mangledString);
		break;
	case AAType:
		auto asAA = cast(ir.AAType) t;
		assert(asAA !is null);
		mangledString ~= "H";
		mangleBase(asAA.key, names, mangledString);
		mangleBase(asAA.value, names, mangledString);
		break;
	case StaticArrayType:
		auto asSA = cast(ir.StaticArrayType) t;
		assert(asSA !is null);
		mangledString ~= "G";
		mangledString ~= to!string(asSA.length);
		mangleBase(asSA.base, names, mangledString);
		break;
	case StorageType:
		auto asST = cast(ir.StorageType) t;
		assert(asST !is null);
		mangleBase(asST.base, names, mangledString);
		break;
	default:
		mangledString = "unknown" ~ to!string(t.nodeType);
		break;
	}
}

void mangleFunctionType(ir.FunctionType fn, string[] names, ref string mangledString)
{
	mangleLinkage(fn.linkage, mangledString);
	if (fn.hiddenParameter) {
		mangledString ~= "M";
	}
	// !!! Attributes go here. !!!
	foreach (i, param; fn.params) {
		mangleBase(param.type, names, mangledString);
	}
	mangledString ~= "Z";  // This would be difference with variadics.
	mangleBase(fn.ret, names, mangledString);
}

void mangleDelegateType(ir.DelegateType fn, string[] names, ref string mangledString)
{
	mangledString ~= "D";
	mangleLinkage(fn.linkage, mangledString);
	// !!! Attributes go here. !!!
	foreach (param; fn.params) {
		mangleBase(param.type, names, mangledString);
	}
	mangledString ~= "Z";  // This would be difference with variadics.
	mangleBase(fn.ret, names, mangledString);
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
