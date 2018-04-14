/*#D*/
// Copyright 2013-2016, Bernard Helyer.
// Copyright 2013-2016, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volta.ir.printer;

import watt.conv : toLower;
import watt.text.format : format;
import watt.text.sink : StringSink, Sink;

import ir = volta.ir;
import volta.ir.token : tokenToString, TokenType;


string printType(ir.Type type, bool alwaysGlossed = false)
{
	StringSink sink;
	write(sink.sink, type, alwaysGlossed);
	return sink.toString();
}

void write(Sink sink, ir.Type type, bool alwaysGlossed)
{
	if (type is null) {
		sink("(null)");
		return;
	}
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

	switch(type.nodeType) with(ir.NodeType) {
	case PrimitiveType:
		ir.PrimitiveType prim = cast(ir.PrimitiveType)type;
		if (prim.originalToken.type != TokenType.None) {
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
	case Interface:
		auto agg = cast(ir.Aggregate)type;
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


string binopToString(ir.BinOp.Op op)
{
	final switch (op) with (ir.BinOp.Op) {
	case None: return "<none>";
	case Assign: return "=";
	case AddAssign: return "+=";
	case SubAssign: return "-=";
	case MulAssign: return "*=";
	case DivAssign: return "/=";
	case ModAssign: return "%=";
	case OrAssign: return "|=";
	case AndAssign: return "&=";
	case XorAssign: return "^=";
	case CatAssign: return "~=";
	case LSAssign: return "<<=";
	case SRSAssign: return ">>=";
	case RSAssign: return ">>>=";
	case PowAssign: return "^^=";
	case OrOr: return "||";
	case AndAnd: return "&&";
	case Or: return "|";
	case Xor: return "^";
	case And: return "&";
	case Equal: return "==";
	case NotEqual: return "!=";
	case Is: return "is";
	case NotIs: return "!is";
	case Less: return "<";
	case LessEqual: return "<=";
	case GreaterEqual: return ">=";
	case Greater: return ">";
	case In: return "in";
	case NotIn: return "!in";
	case LS: return "<<";
	case RS: return ">>";
	case SRS: return ">>>";
	case Add: return "+";
	case Sub: return "-";
	case Cat: return "~";
	case Mul: return "*";
	case Div: return "/";
	case Mod: return "%";
	case Pow: return "^^";
	}
}
