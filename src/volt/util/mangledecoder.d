module volt.util.mangledecoder;

import watt.conv : toInt;
import watt.text.ascii : isDigit;
import watt.text.sink : StringSink;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.token.location;


//! Take the first n characters from s, advance s by n characters, and return the result.
string take(ref string s, size_t n)
{
	assert(s.length >= n);
	auto result = s[0 .. n];
	s = s[n .. $];
	return result;
}

int takeDigit(ref string mangledString)
{
	StringSink numbuf;
	while (mangledString[0].isDigit()) {
		numbuf.sink([mangledString[0]]);
		mangledString = mangledString[1 .. $];
	}
	return toInt(numbuf.toString());
}

ir.Identifier takeNameSegment(ref string mangledString)
{
	int count = mangledString.takeDigit();

	auto ident = new ir.Identifier();
	ident.value = mangledString.take(cast(size_t)count);
	return ident;
}

ir.QualifiedName takeName(ref string mangledString)
{
	auto qname = new ir.QualifiedName();
	while (mangledString[0].isDigit()) {
		qname.identifiers ~= mangledString.takeNameSegment();
	}
	return qname;
}

ir.Declaration mangledToDeclaration(string mangledString)
{
	auto exportTag = mangledString.take(2);
	auto name = mangledString.takeName();

	if (exportTag == "Vv") {
		auto var = mangledString.mangledToVariable();
		var.name = name.identifiers[$-1].value;
		return var;
	} else if (exportTag == "Vf") {
		auto func = new ir.Function();
		func.name = name.identifiers[$-1].value;
		func.type = cast(ir.FunctionType) mangledString.mangleToCallable();
		assert(func.type !is null);
		return func;
	}

	assert(false);
}

ir.Variable mangledToVariable(string mangledString)
{
	auto var = new ir.Variable();
	bool isRef;
	if (mangledString[0] == 'r') {
		mangledString.take(1);
		isRef = true;
	}
	var.type = mangledString.mangledToType();
	if (isRef) {
		auto storage = new ir.StorageType();
		storage.loc = var.type.loc;
		storage.type = ir.StorageType.Kind.Ref;
		storage.base = var.type;
		var.type = storage;
	}
	return var;
}

ir.Type mangledToType(ref string mangledString)
{
	Location loc;
	switch (mangledString.take(1)) {
	case "b":
		return buildByte(loc);
	case "s":
		return buildShort(loc);
	case "i":
		return buildInt(loc);
	case "l":
		return buildLong(loc);
	case "v":
		return buildVoid(loc);
	case "c":
		return buildChar(loc);
	case "d":
		return buildDchar(loc);
	case "w":
		return buildWchar(loc);
	case "f":
		switch (mangledString.take(1)) {
		case "f":
			return buildFloat(loc);
		case "d":
			return buildDouble(loc);
		case "r":
			return buildReal(loc);
		default:
			assert(false);
		}
	case "u":
		switch (mangledString.take(1)) {
		case "b":
			return buildUbyte(loc);
		case "s":
			return buildUshort(loc);
		case "i":
			return buildUint(loc);
		case "l":
			return buildUlong(loc);
		default:
			assert(false);
		}
	case "p":
		return buildPtrSmart(loc, mangledString.mangledToType());
	case "a":
		if (mangledString[0] == 't') {
			mangledString.take(1);
			auto length = cast(size_t)mangledString.takeDigit();
			return buildStaticArrayTypeSmart(loc, length, mangledString.mangledToType());
		}
		return buildArrayTypeSmart(loc, mangledString.mangledToType());
	case "A":
		if (mangledString[0] == 'a') {
			mangledString.take(1);
			ir.Type key = mangledString.mangledToType();
			ir.Type value = mangledString.mangledToType();
			return buildAATypeSmart(loc, key, value);
		} else {
			assert(false, "annotation");
		}
	case "e":
		return buildStorageType(loc, ir.StorageType.Kind.Scope, mangledString.mangledToType());
	case "o":
		return buildStorageType(loc, ir.StorageType.Kind.Const, mangledString.mangledToType());
	case "m":
		return buildStorageType(loc, ir.StorageType.Kind.Immutable, mangledString.mangledToType());
	case "n":
		return buildStorageType(loc, ir.StorageType.Kind.Immutable, mangledString.mangledToType());
	case "r":
		assert(false, "ref");
	case "E":
		auto qname = mangledString.takeName();
		auto _enum = new ir.Enum();
		_enum.name = qname.identifiers[$-1].value;
		return _enum;
	case "C":
		auto qname = mangledString.takeName();
		auto _class = new ir.Class();
		_class.name = qname.identifiers[$-1].value;
		return _class;
	case "S":
		auto qname = mangledString.takeName();
		auto _struct = new ir.Struct();
		_struct.name = qname.identifiers[$-1].value;
		return _struct;
	case "U":
		auto qname = mangledString.takeName();
		auto _union = new ir.Union();
		_union.name = qname.identifiers[$-1].value;
		return _union;
	case "I":
		auto qname = mangledString.takeName();
		auto _iface = new ir._Interface();
		_iface.name = qname.identifiers[$-1].value;
		return _iface;
	case "F", "D":
		return mangledString.mangleToCallable();
	default:
		assert(false);
	}
}

ir.CallableType mangleToCallable(ref string mangledString)
{
	ir.CallableType ctype;
	auto t = mangledString.take(1);
	if (t == "F") {
		ctype = new ir.FunctionType();
	} else if (t == "D") {
		ctype = new ir.DelegateType();
	} else {
		assert(false);
	}

	auto cc = mangledString.take(1);
	switch (cc) {
	case "v":
		ctype.linkage = ir.Linkage.Volt;
		break;
	case "d":
		ctype.linkage = ir.Linkage.D;
		break;
	case "c":
		ctype.linkage = ir.Linkage.C;
		break;
	case "C":
		ctype.linkage = ir.Linkage.CPlusPlus;
		break;
	case "P":
		ctype.linkage = ir.Linkage.Pascal;
		break;
	case "W":
		ctype.linkage = ir.Linkage.Windows;
		break;
	default:
		assert(false);
	}

	while (mangledString[0] != 'X' && mangledString[0] != 'Y' && mangledString[0] != 'Z') {
		ctype.params ~= mangledString.mangledToType();
	}

	auto argsclose = mangledString.take(1);
	switch (argsclose) {
	case "X", "Y": ctype.hasVarArgs = true; break;
	case "Z": break;
	default:
		assert(false);
	}

	ctype.ret = mangledString.mangledToType();

	return ctype;
}
