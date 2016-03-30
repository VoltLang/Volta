module volt.util.mangledecoder;

import watt.conv : toInt;
import watt.text.ascii : isDigit;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.token.location;


/// Take the first n characters from s, advance s by n characters, and return the result.
string take(ref string s, size_t n)
{
	assert(s.length >= n);
	auto result = s[0 .. n];
	s = s[n .. $];
	return result;
}

int takeDigit(ref string mangledString)
{
	char[] numbuf;
	while (mangledString[0].isDigit()) {
		numbuf ~= mangledString[0];
		mangledString = mangledString[1 .. $];
	}
	return toInt(numbuf);
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
		storage.location = var.type.location;
		storage.type = ir.StorageType.Kind.Ref;
		storage.base = var.type;
		var.type = storage;
	}
	return var;
}

ir.Type mangledToType(ref string mangledString)
{
	Location location;
	switch (mangledString.take(1)) {
	case "b":
		return buildByte(location);
	case "s":
		return buildShort(location);
	case "i":
		return buildInt(location);
	case "l":
		return buildLong(location);
	case "v":
		return buildVoid(location);
	case "c":
		return buildChar(location);
	case "d":
		return buildDchar(location);
	case "w":
		return buildWchar(location);
	case "f":
		switch (mangledString.take(1)) {
		case "f":
			return buildFloat(location);
		case "d":
			return buildDouble(location);
		case "r":
			return buildReal(location);
		default:
			assert(false);
		}
	case "u":
		switch (mangledString.take(1)) {
		case "b":
			return buildUbyte(location);
		case "s":
			return buildUshort(location);
		case "i":
			return buildUint(location);
		case "l":
			return buildUlong(location);
		default:
			assert(false);
		}
		assert(false);
	case "p":
		return buildPtrSmart(location, mangledString.mangledToType());
	case "a":
		if (mangledString[0] == 't') {
			mangledString.take(1);
			auto length = cast(size_t)mangledString.takeDigit();
			return buildStaticArrayTypeSmart(location, length, mangledString.mangledToType());
		}
		return buildArrayTypeSmart(location, mangledString.mangledToType());
	case "A":
		if (mangledString[0] == 'a') {
			mangledString.take(1);
			ir.Type key = mangledString.mangledToType();
			ir.Type value = mangledString.mangledToType();
			return buildAATypeSmart(location, key, value);
		} else {
			auto qname = mangledString.takeName();
			auto attr = new ir.UserAttribute();
			attr.name = qname.identifiers[$-1].value;
			return attr;
		}
	case "e":
		return buildStorageType(location, ir.StorageType.Kind.Scope, mangledString.mangledToType());
	case "o":
		return buildStorageType(location, ir.StorageType.Kind.Const, mangledString.mangledToType());
	case "m":
		return buildStorageType(location, ir.StorageType.Kind.Immutable, mangledString.mangledToType());
	case "n":
		return buildStorageType(location, ir.StorageType.Kind.Immutable, mangledString.mangledToType());
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
	assert(false);
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
