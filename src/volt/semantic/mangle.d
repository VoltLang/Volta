/*#D*/
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.mangle;

import watt.conv : toString;
import watt.text.format : format;
import watt.text.sink : Sink, StringSink;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;


/*!
 * Mangle the name of type if not set mangled.
 */
void ensureMangled(ir.Type t)
{
	if (t.mangledName is null) {
		t.mangledName = mangle(t);
	}
}

/*!
 * Mangle a type found in a given module.
 */
string mangle(ir.Type t)
{
	// Special case PrimitiveType, this saves a lot of allocations.
	if (t.nodeType == ir.NodeType.PrimitiveType && !t.isScope) {
		auto asPrim = cast(ir.PrimitiveType) t;
		if (t.isImmutable) {
			return getPrimitiveTypeImmutable(asPrim);
		} else if (t.isConst) {
			assert(!t.isImmutable);
			return getPrimitiveTypeConst(asPrim);
		} else {
			return getPrimitiveType(asPrim);
		}
	}

	StringSink sink;
	version (Volt) {
		mangleType(t, sink.sink);
	} else {
		mangleType(t, &sink.sink);
	}
	return sink.toString();
}

/*!
 * Mangle a Variable found ina given module.
 *
 * @todo figure out what to do about names argument.
 */
string mangle(string[] names, ir.Variable v)
{
	StringSink sink;
	sink.sink("Vv");

	version (Volt) {
		mangleName(names, sink.sink);
		mangleString(v.name, sink.sink);
		mangleType(v.type, sink.sink);
	} else {
		mangleName(names, &sink.sink);
		mangleString(v.name, &sink.sink);
		mangleType(v.type, &sink.sink);
	}
	return sink.toString();
}

/*!
 * Mangle a function.
 *
 * @todo figure out what to do about names argument.
 */
string mangle(string[] names, ir.Function func)
{
	StringSink sink;
	sink.sink("Vf");

	version (Volt) {
		mangleName(names, sink.sink);
		mangleString(func.name, sink.sink);
		mangleType(func.type, sink.sink);
	} else {
		mangleName(names, &sink.sink);
		mangleString(func.name, &sink.sink);
		mangleType(func.type, &sink.sink);
	}
	return sink.toString();
}


private:


void mangleType(ir.Type t, Sink sink)
{
	if (t.isScope) {
		sink("e");
	}
	if (t.isConst) {
		sink("o");
	}
	if (t.isImmutable) {
		sink("m");
	}
	switch (t.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto asPrim = cast(ir.PrimitiveType) t;
		assert(asPrim !is null);
		sink(getPrimitiveType(asPrim));
		break;
	case ArrayType:
		auto asArray = cast(ir.ArrayType) t;
		assert(asArray !is null);
		sink("a");
		mangleType(asArray.base, sink);
		break;
	case NullType:
		auto vptr = buildVoidPtr(/*#ref*/t.loc);
		mangleType(vptr, sink);
		break;
	case PointerType:
		auto asPointer = cast(ir.PointerType) t;
		assert(asPointer !is null);
		sink("p");
		mangleType(asPointer.base, sink);
		break;
	case Struct:
		auto asStruct = cast(ir.Struct) t;
		assert(asStruct !is null);
		sink("S");
		mangleScope(asStruct.myScope, sink);
		break;
	case Union:
		auto asUnion = cast(ir.Union) t;
		assert(asUnion !is null);
		sink("U");
		mangleScope(asUnion.myScope, sink);
		break;
	case Class:
		auto asClass = cast(ir.Class) t;
		assert(asClass !is null);
		sink("C");
		mangleScope(asClass.myScope, sink);
		break;
	case Enum:
		auto asEnum = cast(ir.Enum) t;
		assert(asEnum !is null);
		sink("E");
		mangleScope(asEnum.myScope, sink);
		break;
	case Interface:
		auto asInterface = cast(ir._Interface) t;
		assert(asInterface !is null);
		sink("I");
		mangleScope(asInterface.myScope, sink);
		break;
	case TypeReference:
		auto asTypeRef = cast(ir.TypeReference) t;
		assert(asTypeRef !is null);
		assert(asTypeRef.type !is null);
		mangleType(asTypeRef.type, sink);
		break;
	case DelegateType:
		auto asDelegateType = cast(ir.DelegateType) t;
		assert(asDelegateType !is null);
		mangleDelegateType(asDelegateType, sink);
		break;
	case FunctionType:
		auto asFunctionType = cast(ir.FunctionType) t;
		assert(asFunctionType !is null);
		mangleFunctionType(asFunctionType, sink);
		break;
	case AAType:
		auto asAA = cast(ir.AAType) t;
		assert(asAA !is null);
		sink("Aa");
		mangleType(asAA.key, sink);
		mangleType(asAA.value, sink);
		break;
	case StaticArrayType:
		auto asSA = cast(ir.StaticArrayType) t;
		assert(asSA !is null);
		sink("at");
		sink(toString(asSA.length));
		mangleType(asSA.base, sink);
		break;
	default:
		auto st = cast(ir.StorageType)t;
		throw panicUnhandled(t, format("%s in mangler", ir.nodeToString(t.nodeType)));
	}
}

void mangleFunctionType(ir.FunctionType func, Sink sink)
{
	if (func.hiddenParameter) {
		sink("M");
	}
	sink("F");
	mangleCallableType(func, sink);
}

void mangleDelegateType(ir.DelegateType func, Sink sink)
{
	sink("D");
	mangleCallableType(func, sink);
}

void mangleCallableType(ir.CallableType ct, Sink sink)
{
	sink(getLinkage(ct.linkage));
	foreach (i, param; ct.params) {
		if (ct.isArgRef[i]) {
			sink("r");
		}
		if (ct.isArgOut[i]) {
			sink("O");
		}
		mangleType(param, sink);
	}
	sink(ct.hasVarArgs ? "Y" : "Z");
	mangleType(ct.ret, sink);
}

void mangleScope(ir.Scope _scope, Sink sink)
{
	assert(_scope !is null);

	if (_scope.parent !is null) {
		mangleScope(_scope.parent, sink);
		mangleString(_scope.name, sink);
		return;
	}

	auto asModule = cast(ir.Module)_scope.node;
	if (asModule is null)
		throw panic(/*#ref*/_scope.node.loc, "top scope is not a module");

	foreach (id; asModule.name.identifiers) {
		mangleString(id.value, sink);
	}
}

void mangleString(string s, Sink sink)
{
	version (Volt) {
		format(sink, "%s%s", s.length, s);
	} else {
		sink(format("%s%s", s.length, s));
	}
}

void mangleName(string[] names, Sink sink)
{
	foreach (name; names) {
		mangleString(name, sink);
	}
}

string getLinkage(ir.Linkage l)
{
	final switch (l) with (ir.Linkage) {
	case Volt: return "v";
	case C: return "c";
	case CPlusPlus: return "C";
	case D: return "d";
	case Windows: return "W";
	case Pascal: return "P";
	case System: assert(false);  // I assume we'll have had a pass removing System by now.
	}
}

string getPrimitiveType(ir.PrimitiveType t)
{
	final switch (t.type) with (ir.PrimitiveType.Kind) {
	case Bool:   return "B";
	case Byte:   return "b";
	case Char:   return "c";
	case Wchar:  return "w";
	case Dchar:  return "d";
	case Double: return "fd";
	case Float:  return "ff";
	case Int:    return "i";
	case Long:   return "l";
	case Real:   return "fr";
	case Short:  return "s";
	case Ubyte:  return "ub";
	case Uint:   return "ui";
	case Ulong:  return "ul";
	case Ushort: return "us";
	case Void:   return "v";
	case Invalid:
		throw panic(t, "invalid primitive kind");
	}
}

string getPrimitiveTypeConst(ir.PrimitiveType t)
{
	final switch (t.type) with (ir.PrimitiveType.Kind) {
	case Bool:   return "oB";
	case Byte:   return "ob";
	case Char:   return "oc";
	case Wchar:  return "ow";
	case Dchar:  return "od";
	case Double: return "ofd";
	case Float:  return "off";
	case Int:    return "oi";
	case Long:   return "ol";
	case Real:   return "ofr";
	case Short:  return "os";
	case Ubyte:  return "oub";
	case Uint:   return "oui";
	case Ulong:  return "oul";
	case Ushort: return "ous";
	case Void:   return "ov";
	case Invalid:
		throw panic(t, "invalid primitive kind");
	}
}

string getPrimitiveTypeImmutable(ir.PrimitiveType t)
{
	final switch (t.type) with (ir.PrimitiveType.Kind) {
	case Bool:   return "mB";
	case Byte:   return "mb";
	case Char:   return "mc";
	case Wchar:  return "mw";
	case Dchar:  return "md";
	case Double: return "mfd";
	case Float:  return "mff";
	case Int:    return "mi";
	case Long:   return "ml";
	case Real:   return "mfr";
	case Short:  return "ms";
	case Ubyte:  return "mub";
	case Uint:   return "mui";
	case Ulong:  return "mul";
	case Ushort: return "mus";
	case Void:   return "mv";
	case Invalid:
		throw panic(t, "invalid primitive kind");
	}
}
