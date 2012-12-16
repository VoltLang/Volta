// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.expression;

import lib.llvm.core;

import volt.exceptions;
import volt.llvm.state;
import volt.llvm.type;
static import volt.semantic.mangle;


/**
 * Represents a single LLVMValueRef plus the associated high level type.
 *
 * A Value can be in reference form where it is actually a pointer
 * to the give value, since all variables are stored as alloca'd
 * memory in a function we will not insert loads until needed.
 * This is needed for '&' to work and struct lookups.
 */
class Value
{
	bool isPointer; ///< Is this a reference to the real value?
	Type type;
	LLVMValueRef value;
}

/**
 * Returns the LLVMValueRef for the given expression,
 * evaluated at the current state.builder location.
 */
LLVMValueRef getValue(State state, ir.Exp exp)
{
	auto v = new Value();

	state.getValue(exp, v);
	return v.value;
}

/**
 * Returns the LLVMValueRef for the given constant expression,
 * does not require that state.builder is set.
 */
LLVMValueRef getConstantValue(State state, ir.Exp exp)
{
	void error() {
		throw CompilerPanic(exp.location, "Could not get constant from expression");
	}

	if (exp.nodeType == ir.NodeType.Constant)
		return getValue(state, exp);
	if (exp.nodeType != ir.NodeType.Unary)
		error();

	auto asUnary = cast(ir.Unary)exp;
	if (asUnary.op != ir.Unary.Op.Cast)
		error();

	auto c = cast(ir.Constant)asUnary.value;
	if (c is null)
		error();

	auto t = state.fromIr(asUnary.type);

	/// @todo actually handle the casts.
	error();
	assert(false);
}

/**
 * Returns the value, making sure that the value is not in
 * reference form, basically inserting load instructions where needed.
 */
void getValue(State state, ir.Exp exp, Value result)
{
	state.getValueAnyForm(exp, result);
	makeNonPointer(state, result);
}

/**
 * Returns the value in reference form, basically meaning that
 * the return value is a pointer to where it is held in memory.
 */
void getValueRef(State state, ir.Exp exp, Value result)
{
	state.getValueAnyForm(exp, result);

	if (result.isPointer)
		return;
	throw CompilerPanic(exp.location, "Value is not a backend reference");
}

/**
 * Returns the value, without doing any checking if it is
 * in reference form or not.
 */
void getValueAnyForm(State state, ir.Exp exp, Value result)
{
	switch(exp.nodeType) with (ir.NodeType) {
	case BinOp:
		auto bin = cast(ir.BinOp)exp;
		handleBinOp(state, bin, result);
		break;
	case Unary:
		auto unary = cast(ir.Unary)exp;
		handleUnary(state, unary, result);
		break;
	case Postfix:
		auto postfix = cast(ir.Postfix)exp;
		handlePostfix(state, postfix, result);
		break;
	case ExpReference:
		auto expRef = cast(ir.ExpReference)exp;
		handleExpReference(state, expRef, result);
		break;
	case Constant:
		auto cnst = cast(ir.Constant)exp;
		handleConstant(state, cnst, result);
		break;
	default:
		auto str = format("can't getValue from %s", to!string(exp.nodeType));
		throw CompilerPanic(exp.location, str);
	}
}


private:


void handleBinOp(State state, ir.BinOp bin, Value result)
{
	switch(bin.op) with (ir.BinOp.Type) {
	case Assign:
		handleAssign(state, bin, result);
		break;
	case AndAnd:
	case OrOr:
	//case XorXor:
		handleBoolCompare(state, bin, result);
		break;
	case Equal:
	case NotEqual:
	case Less:
	case LessEqual:
	case GreaterEqual:
	case Greater:
		handleCompare(state, bin, result);
		break;
	default:
		handleBinOpFallthrough(state, bin, result);
	}
}

void handleAssign(State state, ir.BinOp bin, Value result)
{
	// Returns the right value instead.
	Value left = new Value();
	Value right = result;

	state.getValueRef(bin.left, left);
	state.getValue(bin.right, right);

	// Not returned.
	LLVMBuildStore(state.builder, right.value, left.value);
}

void handleBoolCompare(State state, ir.BinOp bin, Value result)
{
	Value left = result;
	Value right = new Value();

	state.getValue(bin.left, left);
	state.getValue(bin.right, right);

	switch(bin.op) with (ir.BinOp.Type) {
	case AndAnd:
		result.value = LLVMBuildAnd(state.builder, left.value, right.value, "AndAnd");
		break;
	case OrOr:
		result.value = LLVMBuildOr(state.builder, left.value, right.value, "OrOr");
		break;
	//case XorXor:
	//	result.value = LLVMBuildXor(state.builder, left.value, right.value, "XorXor");
	//	break;
	default:
		throw CompilerPanic(bin.location, "error");
	}
}

void handleCompare(State state, ir.BinOp bin, Value result)
{
	Value left = result;
	Value right = new Value();

	state.getValue(bin.left, left);
	state.getValue(bin.right, right);

	auto pt = cast(PrimitiveType)result.type;
	if (pt is null)
		throw CompilerPanic(bin.location, "can only compare primitive types");

	LLVMIntPredicate pr;
	switch(bin.op) with (ir.BinOp.Type) {
	case Equal:
		pr = LLVMIntPredicate.EQ;
		break;
	case NotEqual:
		pr = LLVMIntPredicate.NE;
		break;
	case Less:
		if (pt.signed)
			pr = LLVMIntPredicate.SLT;
		else
			pr = LLVMIntPredicate.ULT;
		break;
	case LessEqual:
		if (pt.signed)
			pr = LLVMIntPredicate.SLE;
		else
			pr = LLVMIntPredicate.ULE;
		break;
	case GreaterEqual:
		if (pt.signed)
			pr = LLVMIntPredicate.SGE;
		else
			pr = LLVMIntPredicate.UGE;
		break;
	case Greater:
		if (pt.signed)
			pr = LLVMIntPredicate.SGT;
		else
			pr = LLVMIntPredicate.UGT;
		break;
	default:
		throw CompilerPanic(bin.location, "error");
	}

	/// @todo Turn this into a singleton on the state.
	auto irPt = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
	irPt.location = bin.location;
	irPt.mangledName = volt.semantic.mangle.mangle(null, irPt);
	result.type = state.fromIr(irPt);
	result.value = LLVMBuildICmp(state.builder, pr, left.value, right.value, "icmp");
}

void handleBinOpPointer(State state, ir.BinOp bin,
                        Value ptr, Value other, Value result)
{
	auto ptrType = cast(PointerType)ptr.type;
	auto pt = cast(PrimitiveType)other.type;
	if (pt is null)
		throw CompilerPanic("Can only do pointer math with non-pointer");
	if (pt.floating)
		throw CompilerPanic("Can't do pointer math with floating value");

	result.type = ptr.type;
	result.value = LLVMBuildGEP(state.builder, ptr.value, [other.value], "gep");
}

void handleBinOpFallthrough(State state, ir.BinOp bin, Value result)
{
	Value left = result;
	Value right = new Value();

	state.getValue(bin.left, left);
	state.getValue(bin.right, right);

	// Check for pointer math.
	auto ptrType = cast(PointerType)left.type;
	if (ptrType !is null)
		return handleBinOpPointer(state, bin, left, right, result);

	// Note the flipping of args.
	ptrType = cast(PointerType)right.type;
	if (ptrType !is null)
		return handleBinOpPointer(state, bin, right, left, result);

	auto pt = cast(PrimitiveType)result.type;
	if (pt is null)
		throw CompilerPanic(bin.location, "Can only binop on primitive types");

	LLVMOpcode op;
	switch(bin.op) with (ir.BinOp.Type) {
	case Add:
		op = pt.floating ? LLVMOpcode.FAdd : LLVMOpcode.Add;
		break;
	case Sub:
		op = pt.floating ? LLVMOpcode.FSub : LLVMOpcode.Sub;
		break;
	case Mul:
		op = pt.floating ? LLVMOpcode.FMul : LLVMOpcode.Mul;
		break;
	case Div:
		if (pt.floating)
			op = LLVMOpcode.FDiv;
		else if (pt.signed)
			op = LLVMOpcode.SDiv;
		else
			op = LLVMOpcode.UDiv;
		break;
	case Mod:
		if (pt.floating)
			op = LLVMOpcode.FRem;
		else if (pt.signed)
			op = LLVMOpcode.SRem;
		else
			op = LLVMOpcode.URem;
		break;
	case LS:
		assert(!pt.floating);
		op = LLVMOpcode.Shl;
		break;
	case SRS:
		assert(!pt.floating);
		op = LLVMOpcode.AShr;
		break;
	case RS:
		assert(!pt.floating);
		op = LLVMOpcode.LShr;
		break;
	default:
		throw CompilerPanic(bin.location, "Unhandled BinOp type");
	}

	result.value = LLVMBuildBinOp(state.builder, op, left.value, right.value, "binOp");
}

void handleUnary(State state, ir.Unary unary, Value result)
{
	switch(unary.op) with (ir.Unary.Op) {
	case Cast:
		handleCast(state, unary, result);
		break;
	case Dereference:
		handleDereference(state, unary, result);
		break;
	case AddrOf:
		handleAddrOf(state, unary, result);
		break;
	default:
		auto str = format("unhandled Unary op %s", to!string(unary.op));
		throw CompilerPanic(unary.location, str);
	}
}

void handleCast(State state, ir.Unary cst, Value result)
{
	// Start by getting the value.
	state.getValue(cst.value, result);

	auto newType = state.fromIr(cst.type);
	auto oldType = result.type;

	assert(newType !is null);
	assert(oldType !is null);

	/// @todo types are not cached yet.
	if (oldType is newType)
		return;

	auto newTypePrim = cast(PrimitiveType)newType;
	auto oldTypePrim = cast(PrimitiveType)oldType;
	if (newTypePrim !is null &&
	    oldTypePrim !is null)
		return handleCastPrimitive(state, cst, result, newTypePrim, oldTypePrim);

	auto newTypePtr = cast(PointerType)newType;
	auto oldTypePtr = cast(PointerType)oldType;
	if (newTypePtr !is null &&
	    oldTypePtr !is null)
		return handleCastPointer(state, cst, result, newTypePtr, oldTypePtr);

	throw CompilerPanic("Can not handled casts");
}

/**
 * Handle primitive casts, the value to cast is stored in result already.
 */
void handleCastPrimitive(State state, ir.Unary cst, Value result,
                         PrimitiveType newType, PrimitiveType oldType)
{
	void error() {
		string str = "invalid cast";
		throw CompilerPanic(cst.location, str);
	}

	result.type = newType;

	LLVMOpcode op;
	if (newType.boolean) {
		if (oldType.floating) {
			error();
		}
		// Need to insert a test here.
		result.value = LLVMBuildICmp(state.builder,
			LLVMIntPredicate.NE,
			result.value,
			LLVMConstNull(oldType.llvmType), "boolCast");
		return; // No fallthrough.
	} else if (newType.floating) {
		if (oldType.signed) {
			op = LLVMOpcode.SIToFP;
		} else if (!oldType.floating) {
			op = LLVMOpcode.UIToFP;
		} else {
			if (newType.bits < oldType.bits) {
				op = LLVMOpcode.FPTrunc;
			} else if (newType.bits > oldType.bits) {
				op = LLVMOpcode.FPExt;
			} else {
				/// @todo when types are cached make this an error path.
				//error();
				op = LLVMOpcode.BitCast;
			}
		}
	} else if (oldType.floating) {
		if (newType.signed) {
			op = LLVMOpcode.FPToSI;
		} else {
			op = LLVMOpcode.FPToUI;
		}
	} else {
		if (newType.bits < oldType.bits) {
			// Truncate is easy, since it doesn't care about signedness.
			op = LLVMOpcode.Trunc;
		} else if (newType.bits > oldType.bits) {
			// Extend care about signedness of the target type.
			// But only if both are signed, since "cast(int)cast(ubyte)0xff" should yeild 255 not -1.
			if (newType.signed && oldType.signed) {
				op = LLVMOpcode.SExt;
			} else {
				op = LLVMOpcode.ZExt;
			}
		} else if (newType.signed != oldType.signed) {
			// Just bitcast this.
			op = LLVMOpcode.BitCast;
		} else if (newType.bits == oldType.bits) {
			/// @todo when types are cached make this an error path.
			op = LLVMOpcode.BitCast;
		} else {
			error();
		}
	}

	result.value = LLVMBuildCast(state.builder, op, result.value, newType.llvmType, "cast");
}

/**
 * Handle pointer casts. 
 * This is really easy.
 */
void handleCastPointer(State state, ir.Unary cst, Value result,
                       PointerType newType, PointerType oldType)
{
	result.type = newType;
	result.value = LLVMBuildBitCast(state.builder, result.value, newType.llvmType, "ptrCast");
}

/**
 * Handles '*' dereferences.
 */
void handleDereference(State state, ir.Unary de, Value result)
{
	state.getValue(de.value, result);

	auto pt = cast(PointerType)result.type;
	assert(pt !is null);

	result.type = pt.base;
	result.isPointer = true;
}

/**
 * Handles '&' referencing.
 */
void handleAddrOf(State state, ir.Unary de, Value result)
{
	state.getValueRef(de.value, result);

	auto pt = new ir.PointerType();
	pt.base = result.type.irType;
	assert(pt.base !is null);
	pt.mangledName = volt.semantic.mangle.mangle(null, pt);

	result.type = state.fromIr(pt);
	result.isPointer = false;
}

void handlePostfix(State state, ir.Postfix postfix, Value result)
{
	switch(postfix.op) with (ir.Postfix.Op) {
	case Identifier:
		handlePostId(state, postfix, result);
		break;
	case Index:
		handleIndex(state, postfix, result);
		break;
	case Call:
		handleCall(state, postfix, result);
		break;
	case Decrement:
	case Increment:
		handleIncDec(state, postfix, result);
		break;
	default:
		auto str = format("unhandled postfix op %s", to!string(postfix.op));
		throw CompilerPanic(postfix.location, str);
	}
}

void handlePostId(State state, ir.Postfix postfix, Value result)
{
	auto b = state.builder;
	LLVMValueRef v;
	uint index;

	state.getValueAnyForm(postfix.child, result);

	auto st = cast(StructType)result.type;
	if (st is null) {
		auto pt = cast(PointerType)result.type;
		if (pt is null)
			throw CompilerPanic(postfix.child.location, "is not pointer or struct");
		st = cast(StructType)pt.base;
		if (st is null)
			throw CompilerPanic(postfix.child.location, "pointed to value is not a struct");

		// We are looking at a pointer, make sure to load it.
		makeNonPointer(state, result);
		v = result.value;
	} else {
		if (!result.isPointer)
			throw CompilerPanic(postfix.location, "can only access structs on pointers");
		v = result.value;
	}

	index = st.indices[postfix.identifier.value];
	v = LLVMBuildStructGEP(b, v, index, "structGep");

	result.isPointer = true;
	result.type = st.types[index];
	result.value = v;
}

void handleIndex(State state, ir.Postfix postfix, Value result)
{
	Value left = result;
	Value right = new Value();

	assert(postfix.arguments.length == 1);

	state.getValue(postfix.child, left);
	state.getValue(postfix.arguments[0], right);

	auto pt = cast(PointerType)left.type;
	assert(pt !is null);


	result.value = LLVMBuildGEP(state.builder, left.value, [right.value], "gep");
	result.type = pt.base;
	result.isPointer = true;
}

void handleCall(State state, ir.Postfix postfix, Value result)
{
	auto numArgs = postfix.arguments.length; 

	Value[] args;
	LLVMValueRef[] llvmArgs;

	args.length = numArgs;
	llvmArgs.length = numArgs;

	foreach(int i, arg; postfix.arguments) {
		auto v = new Value();
		state.getValue(arg, v);
		args[i] = v;
		llvmArgs[i] = v.value;
	}

	state.getValue(postfix.child, result);
	auto ft = cast(FunctionType)result.type;
	assert(ft !is null);

	result.value = LLVMBuildCall(state.builder, result.value, llvmArgs);
	result.type = ft.ret;
}

void handleIncDec(State state, ir.Postfix postfix, Value result)
{
	LLVMValueRef ptr, store, value;
	bool isInc = postfix.op == ir.Postfix.Op.Increment;

	state.getValueRef(postfix.child, result);

	ptr = result.value;
	value = LLVMBuildLoad(state.builder, ptr, "postfixLoad");

	auto ptrType = cast(PointerType)result.type;
	auto primType = cast(PrimitiveType)result.type;
	if (ptrType !is null) {
		auto v = isInc ? 1 : -1;
		auto c = LLVMConstInt(LLVMInt32TypeInContext(state.context), v, true);
		store = LLVMBuildGEP(state.builder, value, [c], "postfixGep");
	} else if (primType) {
		auto op = isInc ? LLVMOpcode.Add : LLVMOpcode.Sub;
		auto c = primType.fromNumber(state, 1);
		store = LLVMBuildBinOp(state.builder, op, value, c, "postfixBinOp");
	} else {

		throw new CompilerError(postfix.location, "unexpected type of postfix child");
	}

	LLVMBuildStore(state.builder, store, ptr);

	result.isPointer = false;
	result.value = value;
}

void handleExpReference(State state, ir.ExpReference expRef, Value result)
{
	switch(expRef.decl.declKind) with (ir.Declaration.Kind) {
	case Function:
		auto fn = cast(ir.Function)expRef.decl;
		result.value = state.getFunctionValue(fn, result.type);
		break;
	case Variable:
		auto var = cast(ir.Variable)expRef.decl;
		result.isPointer = true;
		result.value = state.getVariableValue(var, result.type);
		break;
	default:
		throw CompilerPanic(expRef.location, "invalid decl type");
	}
}

void handleConstant(State state, ir.Constant cnst, Value result)
{
	assert(cnst.type !is null);

	// All of the error checking should have been
	// done in other passes and unimplemented features
	// is checked for in the called functions.

	result.type = state.fromIr(cnst.type);
	result.value = result.type.fromConstant(state, cnst);
}

/**
 * If the given value isPointer is set build a load function.
 */
void makeNonPointer(State state, Value result)
{
	if (!result.isPointer)
		return;

	result.value = LLVMBuildLoad(state.builder, result.value, "load");
	result.isPointer = false;
}
