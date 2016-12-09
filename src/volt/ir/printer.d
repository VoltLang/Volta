// Copyright © 2013-2016, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.printer;

import watt.conv : toLower;
import watt.text.format : format;
import watt.text.sink : StringSink, Sink;

import ir = volt.ir.ir;
import volt.token.token : tokenToString, TokenType;


string printType(ir.Type type, bool alwaysGlossed = false)
{
	StringSink sink;
	write(sink.sink, type, alwaysGlossed);
	return sink.toString();
}

void write(Sink sink, ir.Type type, bool alwaysGlossed)
{
	string suffix;
	if (type.isConst) {
		sink("const(");
		suffix = ")";
	}
	if (type.isImmutable) {
		sink("immutable(");
		suffix = ")";
	}
	if (type.isScope) {
		sink("scope (");
		suffix = ")";
	}

	if (type.glossedName.length > 0 && alwaysGlossed) {
		sink(type.glossedName);
		sink(suffix);
		return;
	}

	assert(type !is null);
	switch(type.nodeType) with(ir.NodeType) {
	case PrimitiveType:
		ir.PrimitiveType prim = cast(ir.PrimitiveType)type;
		if (prim.originalToken !is null) {
			sink(toLower(tokenToString(prim.originalToken.type)));
		} else {
			sink(toLower(tokenToString(cast(TokenType)prim.type)));
		}
		break;
	case TypeReference:
		ir.TypeReference tr = cast(ir.TypeReference)type;
		sink.write(tr.type, alwaysGlossed);
		break;
	case PointerType:
		ir.PointerType pt = cast(ir.PointerType)type;
		sink.write(pt.base, alwaysGlossed);
		sink("*");
		break;
	case NullType:
		sink("null");
		break;
	case ArrayType:
		ir.ArrayType at = cast(ir.ArrayType)type;
		sink.write(at.base, alwaysGlossed);
		sink("[]");
		break;
	case StaticArrayType:
		ir.StaticArrayType sat = cast(ir.StaticArrayType)type;
		sink.write(sat.base, alwaysGlossed);
		sink("[");
		sink(format("%s", sat.length));
		sink("]");
		break;
	case AAType:
		ir.AAType aat = cast(ir.AAType)type;
		sink.write(aat.value, alwaysGlossed);
		sink("[");
		sink.write(aat.key, alwaysGlossed);
		sink("]");
		break;
	case FunctionType:
	case DelegateType:
		ir.CallableType c = cast(ir.CallableType)type;

		if (type.nodeType == FunctionType) {
			sink("fn (");
		} else {
			sink.write(c.ret, alwaysGlossed);
			sink(type.nodeType == FunctionType ? " function(" : " delegate(");
		}

		if (c.params.length > 0) {
			sink.write(c.params[0], alwaysGlossed);
			foreach (param; c.params[1 .. $]) {
				sink(", ");
				sink.write(param, alwaysGlossed);
			}
		}

		if (type.nodeType == FunctionType) {
			sink(") (");
			sink.write(c.ret, alwaysGlossed);
		}

		sink(")");

		break;
	case StorageType:
		ir.StorageType st = cast(ir.StorageType)type;
		sink(toLower(format("%s", st.type)));
		sink.write(st.base, alwaysGlossed);
		break;
	case Enum:
		auto e = cast(ir.Enum)type;
		sink.write(e.myScope.parent);
		sink(e.name);
		break;
	case Class:
	case Struct:
		auto agg = cast(ir.Aggregate)type;
		assert(agg !is null);
		sink.write(agg.myScope.parent);
		sink(agg.name);
		break;
	default:
		sink(type.toString());
		break;
	}

	sink(suffix);
}

void write(Sink sink, ir.Scope s)
{
	auto m = cast(ir.Module)s.node;
	if (m !is null) {
		foreach (id; m.name.identifiers) {
			sink(id.value);
			sink(".");
		}
	} else {
		sink.write(s.parent);
		sink(s.name);
		sink(".");
	}
}
