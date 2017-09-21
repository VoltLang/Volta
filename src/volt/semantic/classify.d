// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.classify;

import watt.text.format : format;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.token.location;

import volt.semantic.context;
import volt.semantic.evaluate;


/*
 *
 * Size and alignment functions.
 *
 */

/*!
 * Returns the size of a given ir.PrimitiveType in bytes.
 */
size_t size(ir.PrimitiveType.Kind kind)
{
	final switch (kind) with (ir.PrimitiveType.Kind) {
	case Void: return 1;
	case Bool: return 1;
	case Char: return 1;
	case Byte: return 1;
	case Ubyte: return 1;
	case Short: return 2;
	case Ushort: return 2;
	case Wchar: return 2;
	case Int: return 4;
	case Uint: return 4;
	case Dchar: return 4;
	case Long: return 8;
	case Ulong: return 8;
	case Float: return 4;
	case Double: return 8;
	case Real: return 8;
	case Invalid: throw panic("invalid primitive kind");
	}
}

/*!
 * Returns the size of a given ir.Type in bytes.
 */
size_t size(TargetInfo target, ir.Node node)
{
	switch (node.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		return size(node.toPrimitiveTypeFast().type);
	case Struct:
		return structSize(target, node.toStructFast());
	case Union:
		return unionSize(target, node.toUnionFast());
	case Enum:
		auto asEnum = node.toEnumFast();
		assert(asEnum.base !is null);
		return size(target, asEnum.base);
	case Variable:
		return size(target, node.toVariableFast().type);
	case Class:
	case AAType:
	case Interface:
	case PointerType:
	case FunctionType:
		return target.isP64 ? 8U : 4U;
	case ArrayType:
	case DelegateType:
		return target.isP64 ? 16U : 8U;
	case TypeReference:
		auto asTR = node.toTypeReferenceFast();
		panicAssert(asTR, asTR.type !is null);
		return size(target, asTR.type);
	case StaticArrayType:
		auto _static = node.toStaticArrayTypeFast();
		return size(target, _static.base) * _static.length;
	default:
		throw panicUnhandled(node, ir.nodeToString(node));
	}
}

/*!
 * Returns the size of a given ir.Struct in bytes.
 * https://en.wikipedia.org/wiki/Data_structure_alignment#Typical_alignment_of_C_structs_on_x86
 */
size_t structSize(TargetInfo target, ir.Struct s)
{
	assert(s.isActualized);
	size_t sizeAccumulator;
	size_t largestAlignment;
	foreach (node; s.members.nodes) {
		// If it's not a Variable, or not a field, it shouldn't take up space.
		auto asVar = node.toVariableChecked();
		if (asVar is null || asVar.storage != ir.Variable.Storage.Field) {
			continue;
		}

		auto sz = size(target, asVar.type);
		auto a = alignment(target, asVar.type);
		if (a > largestAlignment) {
			largestAlignment = a;
		}
		sizeAccumulator = calcAlignment(a, sizeAccumulator) + sz;
	}
	// Round size up to a multiple of the largest size of an aligned member.
	if (largestAlignment == 0) {
		return sizeAccumulator;
	} else {
		return calcAlignment(largestAlignment, sizeAccumulator);
	}
}

/*!
 * Returns the size of a given ir.Union in bytes.
 */
size_t unionSize(TargetInfo target, ir.Union u)
{
	panicAssert(u, u.isActualized);
	size_t sizeAccumulator;
	foreach (node; u.members.nodes) {
		// If it's not a Variable, it shouldn't take up space.
		auto asVar = node.toVariableChecked();
		if (asVar is null || asVar.storage != ir.Variable.Storage.Field) {
			continue;
		}

		auto s = size(target, node);
		if (s > sizeAccumulator) {
			sizeAccumulator = s;
		}
	}
	return sizeAccumulator;
}

/*!
 * Returns the offset adjusted to alignment.
 */
size_t calcAlignment(size_t a, size_t offset)
{
	if (offset % a) {
		return offset + (a - (offset % a));
	} else {
		return offset;
	}
}

/*!
 * Returns the offset adjusted to alignment of type.
 */
size_t calcAlignment(TargetInfo target, ir.Type t, size_t offset)
{
	auto a = alignment(target, t);
	return calcAlignment(a, offset);
}

size_t alignment(TargetInfo target, ir.PrimitiveType.Kind kind)
{
	final switch (kind) with (ir.PrimitiveType.Kind) {
	case Void: return target.alignment.int8;
	case Bool: return target.alignment.int1;
	case Char: return target.alignment.int8;
	case Byte: return target.alignment.int8;
	case Ubyte: return target.alignment.int8;
	case Short: return target.alignment.int16;
	case Ushort: return target.alignment.int16;
	case Wchar: return target.alignment.int16;
	case Int: return target.alignment.int32;
	case Uint: return target.alignment.int32;
	case Dchar: return target.alignment.int32;
	case Long: return target.alignment.int64;
	case Ulong: return target.alignment.int64;
	case Float: return target.alignment.float32;
	case Double: return target.alignment.float64;
	case Real: return target.alignment.float64;
	case Invalid: throw panic("invalid primitive kind");
	}
}

size_t alignment(TargetInfo target, ir.Type node)
{
	switch (node.nodeType) with (ir.NodeType) {
	case Struct:
		return structAlignment(target, node.toStructFast());
	case ArrayType:
	case DelegateType:
	case AAType:
	case PointerType:
	case FunctionType:
	case Class:
	case Interface:
		return target.alignment.ptr;
	case Union:
		return unionAlignment(target, node.toUnionFast());
	case PrimitiveType:
		return alignment(target, node.toPrimitiveTypeFast().type);
	case Enum:
		return alignment(target, node.toEnumFast().base);
	case Variable:
		return alignment(target, node.toVariableFast().type);
	case TypeReference:
		return alignment(target, node.toTypeReferenceFast().type);
	case StaticArrayType:
		return alignment(target, node.toStaticArrayTypeFast().base);
	default:
		throw panicUnhandled(node, ir.nodeToString(node));
	}
}

/*!
 * Returns the size of a given ir.Struct in bytes.
 */
size_t structAlignment(TargetInfo target, ir.Struct s)
{
	panicAssert(s, s.isActualized);

	size_t accumulator = 1;
	foreach (node; s.members.nodes) {
		// If it's not a Variable, or not a field, it shouldn't take up space.
		auto asVar = node.toVariableChecked();
		if (asVar is null || asVar.storage != ir.Variable.Storage.Field) {
			continue;
		}

		auto a = alignment(target, asVar.type);
		if (a > accumulator) {
			accumulator = a;
		}
	}
	return accumulator;
}

/*!
 * Returns the size of a given ir.Union in bytes.
 */
size_t unionAlignment(TargetInfo target, ir.Union u)
{
	panicAssert(u, u.isResolved);

	size_t accumulator = 1;
	foreach (node; u.members.nodes) {
		// If it's not a Variable, or not a field, it shouldn't take up space.
		auto asVar = node.toVariableChecked();
		if (asVar is null || asVar.storage != ir.Variable.Storage.Field) {
			continue;
		}

		auto a = alignment(target, asVar.type);
		if (a > accumulator) {
			accumulator = a;
		}
	}
	return accumulator;
}

/*
 *
 * Type classifier functions.
 *
 */

bool isValidWithExp(ir.Exp exp)
{
	if (exp.nodeType == ir.NodeType.StoreExp ||
	    exp.nodeType == ir.NodeType.ExpReference ||
	    exp.nodeType == ir.NodeType.AccessExp) {
		return true;
	} else if (exp.nodeType == ir.NodeType.Postfix) {
		// TODO Remove Postfix.Identifier case
		auto p = exp.toPostfixFast();
		return p.op == ir.Postfix.Op.Identifier;
	} else {
		return false;
	}
}

/*!
 * Remove types masking a type (e.g. enum).
 */
ir.Type realType(ir.Type t, bool stripEnum = true)
{
	if (t is null) {
		return null;
	}

	switch (t.nodeType) with (ir.NodeType) {
	case TypeReference:
		auto tr = t.toTypeReferenceFast();
		return realType(tr.type, stripEnum);
	case Enum:
		if (!stripEnum) {
			return t;
		}
		auto e = t.toEnumFast();
		return realType(e.base, stripEnum);
	default:
		return t;
	}
}

/*!
 * struct Struct { ... }
 * a := Struct(12);  // isValueExp() == false
 * b := a(12);  // isValueExp() == true, despite the same type.
 */
bool isValueExp(ir.Exp exp)
{
	switch (exp.nodeType) {
	case ir.NodeType.StoreExp:
		return false;
	default:
		return true;
	}
}

/*!
 * A type without mutable indirection is a pure value type --
 * it cannot mutate any other memory than its own, or is composed
 * of the above. This is useful for making const and friends more
 * user friendly.
 *
 * Given a Variable with a const type that does not have mutableIndirection
 * it is safe to copy that value and pass it to a non-const function, like so:
 *
 * void bar(int f);
 * void foo(const(int) i) { bar(i); }
 */
bool mutableIndirection(ir.Type t)
{
	assert(t !is null);
	switch (t.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		return false;
	case TypeReference:
		return mutableIndirection(t.toTypeReferenceFast().type);
	case Struct:
		auto asStruct = t.toStructFast();
		assert(asStruct.isActualized);
		foreach (node; asStruct.members.nodes) {
			auto asVar = node.toVariableChecked();
			if (asVar is null ||
			    asVar.storage != ir.Variable.Storage.Field) {
				continue;
			}
			if (mutableIndirection(asVar.type)) {
				return true;
			}
		}
		return false;
	case Union:
		auto asUnion = t.toUnionFast();
		assert(asUnion.isActualized);
		foreach (node; asUnion.members.nodes) {
			auto asVar = node.toVariableChecked();
			if (asVar is null ||
			    asVar.storage != ir.Variable.Storage.Field) {
				continue;
			}
			if (mutableIndirection(asVar.type)) {
				return true;
			}
		}
		return false;
	case AutoType:
		auto asAutoType = t.toAutoTypeFast();
		assert(asAutoType.explicitType !is null);
		if (asAutoType.isConst || asAutoType.isImmutable) {
			return false;
		}
		if (asAutoType.explicitType is null) {
			return false;
		}
		return mutableIndirection(asAutoType.explicitType);
	default:
		return true;
	}
}

bool isAuto(ir.Type t)
{
	auto a = t.toAutoTypeChecked();
	return a !is null && a.explicitType is null;
}

bool isBool(ir.Type t)
{
	auto p = t.toPrimitiveTypeChecked();
	if (p is null) {
		return false;
	}
	return p.type == ir.PrimitiveType.Kind.Bool;
}

//! Is this an array of characters?
bool isString(ir.Type t)
{
	auto arr = realType(t).toArrayTypeChecked();
	if (arr is null) {
		return false;
	}
	return isChar(arr.base);
}

//! Is this type a character type?
bool isChar(ir.Type t)
{
	auto prim = realType(t).toPrimitiveTypeChecked();
	if (prim is null) {
		return false;
	}
	return prim.type == ir.PrimitiveType.Kind.Char ||
	       prim.type == ir.PrimitiveType.Kind.Wchar ||
	       prim.type == ir.PrimitiveType.Kind.Dchar;
}

bool isArray(ir.Type t)
{
	return t.nodeType == ir.NodeType.ArrayType;
}

bool effectivelyConst(ir.Type type)
{
	return type.isConst || type.isImmutable;
}

bool isPointer(ir.Type t)
{
	return t.nodeType == ir.NodeType.PointerType;
}

bool isIntegral(ir.Type t)
{
	auto prim = t.toPrimitiveTypeChecked();
	if (prim is null) {
		return false;
	}
	return isIntegral(prim.type);
}

bool isIntegralOrBool(ir.Type t)
{
	auto prim = t.toPrimitiveTypeChecked();
	if (prim is null) {
		return false;
	}
	return isIntegralOrBool(prim.type);
}

bool isIntegral(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
	case Byte:
	case Ubyte:
	case Short:
	case Ushort:
	case Int:
	case Uint:
	case Long:
	case Ulong:
	case Char:
	case Wchar:
	case Dchar:
		return true;
	default:
		return false;
	}
}

bool isIntegralOrBool(ir.PrimitiveType.Kind kind)
{
	if (kind == ir.PrimitiveType.Kind.Bool) {
		return true;
	} else {
		return isIntegral(kind);
	}
}

bool isFloatingPoint(ir.Type t)
{
	auto prim = t.toPrimitiveTypeChecked();
	if (prim is null) {
		return false;
	}
	return isFloatingPoint(prim.type);
}

bool isF32(ir.Type t)
{
	auto prim = t.toPrimitiveTypeChecked();
	if (prim is null) {
		return false;
	}
	return prim.type == ir.PrimitiveType.Kind.Float;
}

bool isFloatingPoint(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
	case Float:
	case Double:
	case Real:
		return true;
	default:
		return false;
	}
}

bool isUnsigned(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
	case Void:
	case Byte:
	case Short:
	case Int:
	case Long:
	case Float:
	case Double:
	case Real:
		return false;
	default:
		return true;
	}
}

bool isOkayForPointerArithmetic(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
	case Byte:
	case Ubyte:
	case Short:
	case Ushort:
	case Int:
	case Uint:
	case Long:
	case Ulong:
		return true;
	default:
		return false;
	}
}

bool isAggregate(ir.Type type)
{
	switch (type.nodeType) {
	case ir.NodeType.Struct:
	case ir.NodeType.Union:
	case ir.NodeType.Interface:
	case ir.NodeType.Class:
		return true;
	default:
		return false;
	}
}

bool isInt(ir.Type type)
{
	auto primitive = type.toPrimitiveTypeChecked();
	if (primitive is null) {
		return false;
	}
	return primitive.type == ir.PrimitiveType.Kind.Int;
}

bool isVoid(ir.Type type)
{
	if (type.nodeType != ir.NodeType.PrimitiveType) {
		return false;
	}
	auto primitive = type.toPrimitiveTypeFast();
	return primitive.type == ir.PrimitiveType.Kind.Void;
}

/*!
 * Making the code more readable.
 */
enum IgnoreStorage = true;

/*!
 * Determines whether the two given types are the same.
 *
 * Not similar. Not implicitly convertable. The _same_ type.
 * Returns: true if they're the same, false otherwise.
 */
bool typesEqual(ir.Type a, ir.Type b, bool ignoreStorage = false)
{
	if (!ignoreStorage) {
		if (a.isConst != b.isConst ||
		    a.isImmutable != b.isImmutable ||
		    a.isScope != b.isScope) {
			return false;
		}
	}
	if (a is b) {
		return true;
	}

	auto ant = a.nodeType;
	auto bnt = b.nodeType;
	if (ant == bnt) {
		// Fallthrough to switch case below.
	} else if (ant == ir.NodeType.TypeReference) {
		// Need to discard any TypeReference on either side.
		auto ap = a.toTypeReferenceFast();
		assert(ap.type !is null);
		return typesEqual(ap.type, b, ignoreStorage);
	} else if (bnt == ir.NodeType.TypeReference) {
		// Need to discard any TypeReference on either side.
		auto bp = b.toTypeReferenceFast();
		assert(bp !is null);
		return typesEqual(a, bp.type, ignoreStorage);
	} else {
		return false;
	}

	assert(ant == bnt);

	switch (ant) with (ir.NodeType) {
	case PrimitiveType:
		auto ap = a.toPrimitiveTypeFast();
		auto bp = b.toPrimitiveTypeFast();
		return ap.type == bp.type;
	case StaticArrayType:
		auto ap = a.toStaticArrayTypeFast();
		auto bp = b.toStaticArrayTypeFast();
		return ap.length == bp.length && typesEqual(ap.base, bp.base, ignoreStorage);
	case PointerType:
		auto ap = a.toPointerTypeFast();
		auto bp = b.toPointerTypeFast();
		return typesEqual(ap.base, bp.base, ignoreStorage);
	case ArrayType:
		auto ap = a.toArrayTypeFast();
		auto bp = b.toArrayTypeFast();
		return typesEqual(ap.base, bp.base, ignoreStorage);
	case AAType:
		auto ap = a.toAATypeFast();
		auto bp = b.toAATypeFast();
		return typesEqual(ap.key, bp.key, ignoreStorage) &&
		       typesEqual(ap.value, bp.value, ignoreStorage);
	case TypeReference:
		auto ap = a.toTypeReferenceFast();
		auto bp = b.toTypeReferenceFast();
		assert(ap.type !is null && bp.type !is null);
		return typesEqual(ap.type, bp.type, ignoreStorage);
	case FunctionType:
	case DelegateType:
		auto ap = a.toCallableTypeFast();
		auto bp = b.toCallableTypeFast();

		size_t apLength = ap.params.length;
		size_t bpLength = bp.params.length;
		if (apLength != bpLength) {
			return false;
		}
		if (ap.hiddenParameter != bp.hiddenParameter) {
			return false;
		}
		if (!typesEqual(ap.ret, bp.ret, ignoreStorage)) {
			return false;
		}
		for (size_t i; i < apLength; i++) {
			if (!typesEqual(ap.params[i], bp.params[i], ignoreStorage)) {
				return false;
			}
		}
		return true;
	case NoType:
		return true;
	default:
		// We can somehow get here, FunctionSets probably, seems to be
		// valid as nothing explodes if we leave it like this.
		return false;
	}

}

int typeToRuntimeConstant(LanguagePass lp, ir.Scope current, ir.Type type)
{
	type = realType(type);
	switch (type.nodeType) with (ir.NodeType) {
	case Struct: return lp.TYPE_STRUCT;
	case Class: return lp.TYPE_CLASS;
	case Interface: return lp.TYPE_INTERFACE;
	case Union: return lp.TYPE_UNION;
	case Enum: return lp.TYPE_ENUM;
	case Attribute: return lp.TYPE_ATTRIBUTE;
	case PrimitiveType:
		auto prim = type.toPrimitiveTypeFast();
		final switch (prim.type) with (ir.PrimitiveType.Kind) {
		case Void: return lp.TYPE_VOID;
		case Ubyte: return lp.TYPE_UBYTE;
		case Byte: return lp.TYPE_BYTE;
		case Char: return lp.TYPE_CHAR;
		case Bool: return lp.TYPE_BOOL;
		case Ushort: return lp.TYPE_USHORT;
		case Short: return lp.TYPE_SHORT;
		case Wchar: return lp.TYPE_WCHAR;
		case Uint: return lp.TYPE_UINT;
		case Int: return lp.TYPE_INT;
		case Dchar: return lp.TYPE_DCHAR;
		case Float: return lp.TYPE_FLOAT;
		case Ulong: return lp.TYPE_ULONG;
		case Long: return lp.TYPE_LONG;
		case Double: return lp.TYPE_DOUBLE;
		case Real: return lp.TYPE_REAL;
		case ir.PrimitiveType.Kind.Invalid:
			throw panic(prim, "invalid primitive kind");
		}
	case PointerType: return lp.TYPE_POINTER;
	case ArrayType: return lp.TYPE_ARRAY;
	case StaticArrayType: return lp.TYPE_STATIC_ARRAY;
	case AAType: return lp.TYPE_AA;
	case FunctionType: return lp.TYPE_FUNCTION;
	case DelegateType: return lp.TYPE_DELEGATE;
	default:
		throw panicUnhandled(type, "typeToRuntimeConstant");
	}
}


/*
 *
 * Expression functions.
 *
 */

/*!
 * Does the given property need to have child set?
 */
bool isMember(ir.PropertyExp prop)
{
	return (prop.getFn !is null &&
	        prop.getFn.kind == ir.Function.Kind.Member) ||
	       (prop.setFns.length > 0 &&
	        prop.setFns[0].kind == ir.Function.Kind.Member);
}

/*!
 * Is the given exp a backend constant, this is the minimum that
 * a backend needs to implement in order to fully support Volt.
 *
 * Backends may support more.
 */
bool isBackendConstant(ir.Exp exp)
{
	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		return true;
	case ExpReference:
		auto eref = exp.toExpReferenceFast();
		if (eref.decl is null) {
			return false;
		}

		switch (eref.decl.nodeType) {
		case Function, EnumDeclaration: return true;
		default: return false;
		}
	case Unary:
		auto unary = exp.toUnaryFast();
		if (unary.op != ir.Unary.Op.Cast) {
			return false;
		}
		return isBackendConstant(unary.value);
	default:
		return false;
	}
}

bool isAssign(ir.Exp exp)
{
	auto bop = exp.toBinOpChecked();
	if (bop is null) {
		return false;
	}
	return bop.op.isAssign();
}

bool isAssign(ir.BinOp.Op op)
{
	switch (op) with (ir.BinOp.Op) {
	case Assign, AddAssign, SubAssign, MulAssign, DivAssign, ModAssign,
		AndAssign, OrAssign, XorAssign, CatAssign, LSAssign, SRSAssign,
		RSAssign, PowAssign:
		return true;
	default:
		return false;
	}
}

bool isAssignable(ir.Exp exp)
{
	return isLValueOrAssignable(exp, true);
}

bool isLValue(ir.Exp exp)
{
	return isLValueOrAssignable(exp, false);
}

bool isLValueOrAssignable(ir.Exp exp, bool assign)
{
	switch (exp.nodeType) {
	case ir.NodeType.AccessExp:
		return true;
	case ir.NodeType.IdentifierExp:
		throw panic(exp, "IdentifierExp left in ir (run ExTyper)");
	case ir.NodeType.ExpReference:
		auto eref = exp.toExpReferenceFast();
		return eref.decl.nodeType != ir.NodeType.EnumDeclaration;
	case ir.NodeType.Postfix:
		// TODO Remove Postfix.Identifier case
		auto asPostfix = exp.toPostfixFast();
		return asPostfix.op == ir.Postfix.Op.Identifier ||
		       asPostfix.op == ir.Postfix.Op.Index ||
		       (asPostfix.op == ir.Postfix.Op.Slice && assign);
	case ir.NodeType.Unary:
		auto asUnary = exp.toUnaryFast();
		if (asUnary.op == ir.Unary.Op.Dereference) {
			return true;
		}
		// TODO this is probably not true.
		return isLValueOrAssignable(asUnary.value, assign);
	case ir.NodeType.StatementExp:
		auto sexp = exp.toStatementExpFast();
		return isLValueOrAssignable(sexp.exp, assign);
	default:
		return false;
	}
}

bool isRefVar(ir.Exp exp)
{
	auto asExpRef = exp.toExpReferenceChecked();
	if (asExpRef is null) {
		return false;
	}
	auto asVar = asExpRef.decl.toFunctionParamChecked();
	if (asVar is null) {
		return false;
	}
	return asVar.func.type.isArgRef[asVar.index] || asVar.func.type.isArgOut[asVar.index];
}


bool isComparison(ir.BinOp.Op t)
{
	switch (t) with (ir.BinOp.Op) {
	case OrOr, AndAnd, Equal, NotEqual, Is, NotIs, Less, LessEqual, Greater, GreaterEqual:
		return true;
	default:
		return false;
	}
}

bool isConstant(ir.Exp e)
{
	auto eref = e.toExpReferenceChecked();
	if (eref !is null) {
		auto var = eref.decl.toVariableChecked();
		if (var !is null && var.assign !is null) {
			return isConstant(var.assign);
		}
	}
	return e.nodeType == ir.NodeType.Constant || e.nodeType == ir.NodeType.Typeid || e.nodeType == ir.NodeType.ClassLiteral;
}


bool isValidPointerArithmeticOperation(ir.BinOp.Op t)
{
	switch (t) with (ir.BinOp.Op) {
	case Add, Sub, AddAssign, SubAssign:
		return true;
	default:
		return false;
	}
}

bool isImplicitlyConvertable(ir.Type from, ir.Type to)
{
	auto fprim = from.toPrimitiveTypeChecked();
	auto tprim = to.toPrimitiveTypeChecked();

	if (fprim is null || tprim is null) {
		return false;
	}

	auto fromsz = size(fprim.type);
	auto tosz = size(tprim.type);
	
	if (isIntegralOrBool(from) && isIntegral(to)) {
		// to is unsigned.
		if (isUnsigned(tprim.type)) {
			if (isUnsigned(fprim.type)) {
				// uint is implicitly convertable to uint
				return fromsz <= tosz;
			} else {
				// can not implicitly cast signed to unsigned.
				return false;
			}
		}

		// to is signed.
		if (isUnsigned(fprim.type)) {
			// ushort is implicitly convertable to uint
			return fromsz < tosz;
		} else {
			// int is implicitly convertable to int
			return fromsz <= tosz;
		}
	}
	
	if (isFloatingPoint(from) && isFloatingPoint(to))
		return fromsz <= tosz;

	if (isFloatingPoint(from) && isIntegral(to))
		return false;

	if (isIntegral(from) && isFloatingPoint(to))
		return true;

	// also arrays go here
	return false;
}

bool fitsInPrimitive(TargetInfo target, ir.PrimitiveType t, ir.Exp e)
{
	ir.Constant removeCast(ir.Exp exp)
	{
		auto constant = exp.toConstantChecked();
		if (constant !is null) {
			return constant;
		}
		auto eref = exp.toExpReferenceChecked();
		if (eref !is null && eref.decl.nodeType == ir.NodeType.EnumDeclaration) {
			auto edecl = eref.decl.toEnumDeclarationFast();
			return removeCast(edecl.assign);
		}
		auto unary = exp.toUnaryChecked();
		if (unary !is null) {
			return foldUnary(exp, unary, target);
		}
		return null;
	}

	auto ternary = e.toTernaryChecked();
	if (ternary !is null) {
		return fitsInPrimitive(target, t, ternary.ifTrue) && fitsInPrimitive(target, t, ternary.ifFalse);
	}

	auto constant = removeCast(e);
	if (constant is null) {
		return false;
	}

	auto primitive = constant.type.toPrimitiveTypeChecked();
	if (primitive is null) {
		return false;
	}

	with (ir.PrimitiveType.Kind) {
		bool inUnsignedRange(ulong max)
		{
			if (primitive.type == Byte) {
				return constant.u._byte >= 0 && cast(ulong)constant.u._byte <= max;
			} else if (primitive.type == Ubyte) {
				return constant.u._ubyte <= cast(ubyte)max;
			} else if (primitive.type == Short) {
				return constant.u._short >= 0 && cast(ulong)constant.u._short <= max;
			} else if (primitive.type == Ushort) {
				return constant.u._ushort <= cast(ushort)max;
			} else if (primitive.type == Int) {
				return constant.u._int >= 0 && cast(ulong) constant.u._int <= max;
			} else if (primitive.type == Uint || primitive.type == Dchar) {
				return constant.u._uint <= max;
			} else if (primitive.type == Long) {
				return constant.u._long >= 0 && cast(ulong) constant.u._long <= max;
			} else if (primitive.type == Ulong) {
				return constant.u._ulong <= max;
			} else if (primitive.type == Float || primitive.type == Double) {
				return false;
			} else if (primitive.type == Char) {
				return true;
			} else if (primitive.type == Dchar) {
				return constant.u._uint < cast(uint) max;
			} else if (primitive.type == Bool) {
				return true;
			} else {
				assert(false);
			}
		}

		bool inSignedRange(long min, long max)
		{
			if (primitive.type == Byte) {
				return constant.u._byte >= min && constant.u._byte <= max;
			} else if (primitive.type == Ubyte) {
				return constant.u._ubyte <= cast(ubyte)max;
			} else if (primitive.type == Short) {
				return constant.u._short >= min && constant.u._short <= max;
			} else if (primitive.type == Ushort) {
				return constant.u._ushort <= cast(ushort)max;
			} else if (primitive.type == Int) {
				return constant.u._int >= min && constant.u._int <= max;
			} else if (primitive.type == Uint) {
				return constant.u._uint <= cast(uint)max;
			} else if (primitive.type == Long) {
				return constant.u._long >= min && constant.u._long <= max;
			} else if (primitive.type == Ulong) {
				return constant.u._ulong <= cast(ulong)max;
			} else if (primitive.type == Float || primitive.type == Double) {
				return false;
			} else if (primitive.type == Char) {
				return true;
			} else if (primitive.type == Dchar) {
				return constant.u._uint < cast(uint)max;
			} else if (primitive.type == Bool) {
				return true;
			} else {
				assert(false);
			}
		}

		bool inFloatRange()
		{
			switch(primitive.type) {
			case Int:
				return constant.u._int >= float.min_normal && constant.u._int <= float.max;
			case Uint:
				return constant.u._uint >= float.min_normal && constant.u._uint <= float.max;
			case Long:
				return constant.u._long >= float.min_normal && constant.u._long <= float.max;
			case Ulong:
				return constant.u._ulong >= float.min_normal && constant.u._ulong <= float.max;
			case Float:
				return constant.u._float >= float.min_normal && constant.u._float <= float.max;
			case Double:
				return constant.u._double >= float.min_normal && constant.u._double <= float.max;
			case Bool:
				return true;
			default:
				assert(false);
			}
		}

		bool inDoubleRange()
		{
			switch(primitive.type) {
			case Int:
				return constant.u._int >= double.min_normal && constant.u._int <= double.max;
			case Uint:
				return constant.u._uint >= double.min_normal && constant.u._uint <= double.max;
			case Long:
				return constant.u._long >= double.min_normal && constant.u._long <= double.max;
			case Ulong:
				return constant.u._ulong >= double.min_normal && constant.u._ulong <= double.max;
			case Float:
				return constant.u._float >= double.min_normal && constant.u._float <= double.max;
			case Double:
				return constant.u._double >= double.min_normal && constant.u._double <= double.max;
			case Bool:
				return true;
			default:
				assert(false);
			}
		}

		switch (t.type) {
		case Ubyte, Char: return inUnsignedRange(ubyte.max);
		case Byte: return inSignedRange(byte.min, byte.max);
		case Ushort, Wchar: return inUnsignedRange(ushort.max);
		case Short: return inSignedRange(ushort.min, ushort.max);
		case Uint, Dchar: return inUnsignedRange(uint.max);
		case Int: return inSignedRange(int.min, int.max);
		case Ulong: return inUnsignedRange(ulong.max);
		case Long: return inSignedRange(ulong.min, ulong.max);
		case Float: return inFloatRange();
		case Double: return inDoubleRange();
		case Void: return false;
		default:
			return false;
		}
	}
}


/*
 *
 * Function and variable functions.
 *
 */

/*!
 * If the given scope is in a function, return it. Otherwise, return null.
 */
ir.Function getParentFunction(ir.Scope current)
{
	auto func = current.node.toFunctionChecked();
	if (func !is null) {
		return func;
	}

	auto bs = current.node.toBlockStatementChecked();
	if (bs !is null) {
		return getParentFunction(current.parent);
	}

	return null;
}

bool isInFunction(Context ctx)
{
	return ctx.current.node.nodeType == ir.NodeType.Function || ctx.current.node.nodeType == ir.NodeType.BlockStatement;
}


bool isFunctionMemberOrConstructor(ir.Function func)
{
	final switch (func.kind) with (ir.Function.Kind) {
	case Invalid:
		assert(false);
	case Member:
	case Constructor:
	case Destructor:
	case LocalConstructor:
	case LocalDestructor:
	case GlobalConstructor:
	case GlobalDestructor:
		return true;
	case Function:
	case LocalMember:
	case GlobalMember:
	case Nested:
	case GlobalNested:
		return false;
	}
}

bool isFunctionStatic(ir.Function func)
{
	final switch (func.kind) with (ir.Function.Kind) {
	case Invalid:
	case Constructor:
	case Destructor:
	case LocalConstructor:
	case LocalDestructor:
	case GlobalConstructor:
	case GlobalDestructor:
		assert(false);
	case Member:
		return false;
	case Function:
	case LocalMember:
	case GlobalMember:
	case GlobalNested:
	case Nested:
		return true;
	}
}

bool isVariableStatic(ir.Variable var)
{
	final switch (var.storage) with (ir.Variable.Storage) {
	case Invalid:
		assert(false);
	case Field:
		return false;
	case Function:
	case Nested:
	case Local:
	case Global:
		return true;
	}
}

bool isNull(ir.Exp e)
{
	auto constant = e.toConstantChecked();
	if (constant is null) {
		return false;
	}
	return constant.isNull;
}

bool isNested(ir.Variable.Storage s)
{
	return s == ir.Variable.Storage.Nested;
}

//! Returns true if one of fns's types match fnToMatch. False otherwise.
//! (If fns is empty, this function returns false).
bool containsMatchingFunction(ir.Function[] fns, ir.Function fnToMatch)
{
	foreach (func; fns) {
		if (typesEqual(func.type, fnToMatch.type)) {
			return true;
		}
	}
	return false;
}

bool isNested(ir.Function func)
{
	return func.kind == ir.Function.Kind.Nested ||
	       func.kind == ir.Function.Kind.GlobalNested;
}


/*
 *
 * Store functions.
 *
 */

/*!
 * Used to determine whether a store is local to a function and therefore
 * can not be shadowed by a with statement.
 */
bool isStoreLocal(LanguagePass lp, ir.Scope current, ir.Store store)
{
	if (store.kind != ir.Store.Kind.Value) {
		return false;
	}

	auto var = store.node.toVariableFast();
	if (var.storage != ir.Variable.Storage.Function &&
	    var.storage != ir.Variable.Storage.Nested) {
		return false;
	}

	// Yes this is a variable.
	return true;
}


/*
 *
 * Aggregate functions.
 *
 */

//! Retrieves the types of Variables in _struct, in the order they appear.
ir.Type[] getStructFieldTypes(ir.Struct _struct)
{
	ir.Type[] types;

	if (_struct.members !is null) foreach (node; _struct.members.nodes) {
		auto asVar = node.toVariableChecked();
		if (asVar is null ||
		    asVar.storage != ir.Variable.Storage.Field) {
			continue;
		}
		types ~= asVar.type;
		assert(types[$-1] !is null);
	}

	return types;
}

//! Retrieves the Variables in _struct, in the order they appear.
ir.Variable[] getStructFieldVars(ir.Struct _struct)
{
	ir.Variable[] vars;

	if (_struct.members !is null) foreach (node; _struct.members.nodes) {
		auto asVar = node.toVariableChecked();
		if (asVar is null) {
			continue;
		}
		vars ~= asVar;
	}

	return vars;
}

ir.Function[] getStructFunctions(ir.Struct _struct)
{
	ir.Function[] functions;

	if (_struct.members !is null) foreach (node; _struct.members.nodes) {
		auto asFunction = node.toFunctionChecked();
		if (asFunction is null) {
			continue;
		}
		functions ~= asFunction;
	}

	return functions;
}

ir.Function[] getClassFunctions(ir.Class _class)
{
	ir.Function[] functions;

	if (_class.members !is null) foreach (node; _class.members.nodes) {
		auto asFunction = node.toFunctionChecked();
		if (asFunction is null) {
			continue;
		}
		functions ~= asFunction;
	}

	return functions;
}

/*!
 * If the given scope is a function, and that function has a this reference
 * that is a class, return true and set theClass to that class.
 * Otherwise, return false.
 */
bool getMethodParent(ir.Scope _scope, out ir.Class theClass)
{
	auto func = getParentFunction(_scope);
	if (func is null || !isFunctionMemberOrConstructor(func) ||
		func.thisHiddenParameter is null) {
		return false;
	}
	theClass = realType(func.thisHiddenParameter.type).toClassChecked();
	if (theClass is null) {
		return false;
	}
	return true;
}

//! Returns: true if child is a child of parent.
bool inheritsFrom(ir.Class child, ir.Class parent)
{
	if (child is parent)
		return false;

	auto currentClass = child;
	while (currentClass !is null) {
		if (currentClass is parent) {
			return true;
		}
		currentClass = currentClass.parentClass;
	}
	return false;
}

bool isOrInheritsFrom(ir.Class a, ir.Class b)
{
	if (a is b) {
		return true;
	} else {
		return inheritsFrom(a, b);
	}
}

bool isPointerToClass(ir.Type t)
{
	auto ptr = realType(t).toPointerTypeChecked();
	if (ptr is null) {
		return false;
	}
	auto _class = realType(ptr.base).toClassChecked();
	return _class !is null;
}

/*!
 * How far removed from Object is this class?
 */
size_t distanceFromObject(ir.Class _class)
{
	size_t distance;
	while (_class.parent !is null) {
		distance++;
		_class = _class.parentClass;
	}
	return distance;
}

/*!
 * Given two classes, return their closest relative.
 */
ir.Class commonParent(ir.Class a, ir.Class b)
{
	while (!typesEqual(a, b)) {
		if (distanceFromObject(a) > distanceFromObject(b)) {
			a = a.parentClass;
		} else {
			b = b.parentClass;
		}
	}
	return a;
}


ir.Aggregate opOverloadableOrNull(ir.Type t)
{
	auto _agg = cast(ir.Aggregate)realType(t);
	if (_agg is null) {
		return null;
	}
	return _agg;
}

string overloadName(ir.BinOp.Op op)
{
	switch (op) with (ir.BinOp.Op) {
	case Equal:        return "opEquals";
	case Sub:          return "opSub";
	case Add:          return "opAdd";
	case Mul:          return "opMul";
	case Div:          return "opDiv";
	case SubAssign:    return "opSubAssign";
	case AddAssign:    return "opAddAssign";
	case MulAssign:    return "opMulAssign";
	case DivAssign:    return "opDivAssign";
	case Greater:      return "opCmp";
	case GreaterEqual: return "opCmp";
	case Less:         return "opCmp";
	case LessEqual:    return "opCmp";
	default:           return "";
	}
}

string overloadPostfixName(ir.Postfix.Op op)
{
	switch (op) with (ir.Postfix.Op) {
	case Index: return "opIndex";
	case Slice: return "opSlice";
	default: return "";
	}
}

string overloadPostfixAssignName(string oldname)
{
	switch (oldname) {
	case "opIndex": return "opIndexAssign";
	case "opSlice": return "opSliceAssign";
	default: return "";
	}
}

string overloadUnaryMinusName()
{
	return "opNeg";
}

string overloadDollarName()
{
	return "opDollar";
}
