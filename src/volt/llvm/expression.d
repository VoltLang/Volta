// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.expression;

import lib.llvm.core;

import volt.token.location : Location;
import volt.exceptions;
import volt.llvm.type;
import volt.llvm.value;
import volt.llvm.state;
static import volt.semantic.mangle;


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
	case StructLiteral:
		auto sl = cast(ir.StructLiteral)exp;
		handleStructLiteral(state, sl, result);
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
/*
 *
 * BinOp functions.
 *
 */


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
	case AddAssign:
	case SubAssign:
	case MulAssign:
	case DivAssign:
	case ModAssign:
	case AndAssign:
	case OrAssign:
	case XorAssign:
		handleBinOpAssign(state, bin, result);
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
		handleBinOpNonAssign(state, bin, result);
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

	// The frontend should have made sure that both are bools.
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

	result.type = state.boolType;
	result.value = LLVMBuildICmp(state.builder, pr, left.value, right.value, "icmp");
}

void handleBinOpAssign(State state, ir.BinOp bin, Value result)
{
	// We return the left value.
	Value left = result;
	Value right = new Value();
	Value opResult = right;

	state.getValueRef(bin.left, left);
	state.getValueAnyForm(bin.right, right);

	// Copy the left value since the handleBinOpNonAssign
	// function will turn it into a value, and we return
	// it as a lvalue/reference.
	left = new Value(left);

	ir.BinOp.Type op;
	switch (bin.op) with (ir.BinOp.Type) {
	case AddAssign: op = Add; break;
	case SubAssign: op = Sub; break;
	case MulAssign: op = Mul; break;
	case DivAssign: op = Div; break;
	case ModAssign: op = Mod; break;
	case AndAssign: op = And; break;
	case OrAssign: op = Or; break;
	case XorAssign: op = Xor; break;
	default:
		throw CompilerPanic(bin.location, "unhandled assign BipOp type");
	}

	auto pt = cast(PrimitiveType)right.type;
	if (pt is null)
		throw CompilerPanic(bin.location, "right hand value must be of primitive type");

	handleBinOpNonAssign(state, bin.location, op, left, right, right);

	// Not returned.
	LLVMBuildStore(state.builder, right.value, result.value);
}

void handleBinOpNonAssign(State state, ir.BinOp bin, Value result)
{
	Value left = new Value();
	Value right = result;

	state.getValueAnyForm(bin.left, left);
	state.getValueAnyForm(bin.right, right);

	handleBinOpNonAssign(state, bin.location, bin.op,
	                       left, right, result);
}

void handleBinOpNonAssign(State state, Location loc, ir.BinOp.Type binOp,
                          Value left, Value right, Value result)
{
	makeNonPointer(state, left);
	makeNonPointer(state, right);

	// Check for pointer math.
	auto ptrType = cast(PointerType)left.type;
	if (ptrType !is null)
		return handleBinOpPointer(state, loc, binOp, left, right, result);

	// Note the flipping of args.
	ptrType = cast(PointerType)right.type;
	if (ptrType !is null)
		return handleBinOpPointer(state, loc, binOp, right, left, result);

	auto pt = cast(PrimitiveType)right.type;
	if (pt is null)
		throw CompilerPanic(loc, "can only binop on primitive types");

	handleBinOpPrimitive(state, loc, binOp, pt, left, right, result);
}

void handleBinOpPointer(State state, Location loc, ir.BinOp.Type binOp,
                        Value ptr, Value other, Value result)
{
	auto ptrType = cast(PointerType)ptr.type;
	auto primType = cast(PrimitiveType)other.type;

	if (ptrType is null)
		throw CompilerPanic(loc, "left value must be of pointer type");
	if (primType is null)
		throw CompilerPanic(loc, "can only do pointer math with non-pointer");
	if (primType.floating)
		throw CompilerPanic(loc, "can't do pointer math with floating value");
	if (binOp != ir.BinOp.Type.Add)
		throw CompilerPanic(loc, "can only add to pointers");

	// Either ptr or other could be result, keep that in mind.
	result.type = ptr.type;
	result.value = LLVMBuildGEP(state.builder, ptr.value, [other.value], "gep");
}

void handleBinOpPrimitive(State state, Location loc, ir.BinOp.Type binOp,
                          PrimitiveType pt,
	                      Value left, Value right, Value result)
{
	LLVMOpcode op;
	switch(binOp) with (ir.BinOp.Type) {
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
		throw CompilerPanic(loc, "unhandled BinOp type");
	}

	// Either right or left could be result, keep that in mind.
	result.type = right.type;
	result.value = LLVMBuildBinOp(state.builder, op, left.value, right.value, "binOp");
}


/*
 *
 * Unary functions.
 *
 */


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
	case Plus:
	case Minus:
		handlePlusMinus(state, unary, result);
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
	auto newTypeFn = cast(FunctionType)newType;
	auto oldTypeFn = cast(FunctionType)oldType;
	if ((newTypePtr !is null || newTypeFn !is null) &&
	    (oldTypePtr !is null || oldTypeFn !is null))
		return handleCastPointer(state, cst, result, newType);

	throw CompilerPanic("Unhandlable cast.");
}

/**
 * Handle primitive casts, the value to cast is stored in result already.
 */
void handleCastPrimitive(State state, ir.Unary cst, Value result,
                         PrimitiveType newType, PrimitiveType oldType)
{
	// No op it.
	if (newType is oldType)
		return;

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
				error(); // Type are the same?
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
		} else {
			error(); // Type are the same?
		}
	}

	result.value = LLVMBuildCast(state.builder, op, result.value, newType.llvmType, "cast");
}

/**
 * Handle pointer casts. 
 * This is really easy.
 * Also casts between function pointers and pointers.
 */
void handleCastPointer(State state, ir.Unary cst, Value result, Type newType)
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

void handlePlusMinus(State state, ir.Unary unary, Value result)
{
	state.getValue(unary.value, result);

	auto primType = cast(PrimitiveType)result.type;
	if (primType is null)
		throw CompilerPanic(unary.location, "must be primitive type");

	// No-op plus
	if (unary.op == ir.Unary.Op.Plus)
		return;

	if (primType.floating)
		result.value = LLVMBuildFNeg(state.builder, result.value, "neg");
	else
		result.value = LLVMBuildNeg(state.builder, result.value, "fneg");
}


/*
 *
 * Postfix functions.
 *
 */


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
	case CreateDelegate:
		handleCreateDelegate(state, postfix, result);
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
		makePointer(state, result);
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
	if (pt is null)
		throw CompilerPanic(postfix.location, "can not index non-pointer type");

	result.value = LLVMBuildGEP(state.builder, left.value, [right.value], "gep");
	result.type = pt.base;
	result.isPointer = true;
}

void handleCreateDelegate(State state, ir.Postfix postfix, Value result)
{
	Value instance = result;
	Value func = new Value();

	state.getStructRef(postfix.child, instance);
	state.getValue(postfix.memberFunction, func);

	auto fn = cast(FunctionType)func.type;
	if (fn is null)
		throw CompilerPanic(postfix.location, "func isn't FunctionType");

	auto irFn = cast(ir.FunctionType)fn.irType;
	auto irDg = new ir.DelegateType();
	irDg.ret = irFn.ret;
	irDg.linkage = irFn.linkage;
	irDg.params = irFn.params[0 .. $-1].dup;
	irDg.mangledName = volt.semantic.mangle.mangle(null, irDg);

	auto dg = cast(DelegateType)state.fromIr(irDg);
	if (dg is null)
		throw CompilerPanic("oh god");

	instance.value = LLVMBuildBitCast(
		state.builder, instance.value, state.voidPtrType.llvmType, "");
	func.value = LLVMBuildBitCast(
		state.builder, func.value, dg.llvmCallPtrType, "");

	auto v = LLVMBuildAlloca(state.builder, dg.llvmType, "");

	auto funcPtr = LLVMBuildStructGEP(
		state.builder, v, dg.funcIndex, "dgFuncGep");
	auto voidPtrPtr = LLVMBuildStructGEP(
		state.builder, v, dg.voidPtrIndex, "dgVoidPtrGep");

	LLVMBuildStore(state.builder, func.value, funcPtr);
	LLVMBuildStore(state.builder, instance.value, voidPtrPtr);

	result.type = dg;
	result.isPointer = true;
	result.value = v;
}

void handleCall(State state, ir.Postfix postfix, Value result)
{
	LLVMValueRef[] llvmArgs;

	llvmArgs.length = postfix.arguments.length;

	foreach(int i, arg; postfix.arguments) {
		auto v = new Value();
		state.getValue(arg, v);
		llvmArgs[i] = v.value;
	}

	// Special case create delegate children to save
	// a bunch of created delegates in the LLVM IR.
	auto childAsPostfix = cast(ir.Postfix)postfix.child;
	if (childAsPostfix !is null &&
	    childAsPostfix.op == ir.Postfix.Op.CreateDelegate) {

		state.getValueRef(childAsPostfix.child, result);
		llvmArgs ~= result.value;

		state.getValue(childAsPostfix.memberFunction, result);

	} else {
		state.getValueAnyForm(postfix.child, result);
	}

	auto ft = cast(FunctionType)result.type;
	auto dt = cast(DelegateType)result.type;

	Type ret;
	if (ft !is null) {
		ret = ft.ret;
		makeNonPointer(state, result);
	} else if (dt !is null) {

		makePointer(state, result);

		ret = dt.ret;

		auto func = LLVMBuildStructGEP(state.builder, result.value, dt.funcIndex, "dgFuncGep");
		auto voidPtr = LLVMBuildStructGEP(state.builder, result.value, dt.voidPtrIndex, "dgVoidPtrGep");

		func = LLVMBuildLoad(state.builder, func, "dgFuncGep");
		voidPtr = LLVMBuildLoad(state.builder, voidPtr, "dgVoidGep");

		llvmArgs ~= voidPtr;
		result.value = func;
	} else {
		throw CompilerPanic(postfix.location, "can not call this thing");
	}

	result.value = LLVMBuildCall(state.builder, result.value, llvmArgs);
	result.isPointer = false;
	result.type = ret;
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
	} else if (primType !is null) {
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


/*
 *
 * Misc functions.
 *
 */


void handleExpReference(State state, ir.ExpReference expRef, Value result)
{
	switch(expRef.decl.declKind) with (ir.Declaration.Kind) {
	case Function:
		auto fn = cast(ir.Function)expRef.decl;
		result.isPointer = false;
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

/**
 * Gets the value for the expressions and makes sure that
 * it is a struct reference value. Will handle pointers to
 * structs correctly, setting isPointer to true and
 * dereferencing the type pointer to the actual StructType.
 */
void getStructRef(State state, ir.Exp exp, Value result)
{
	getValueAnyForm(state, exp, result);

	auto strct = cast(StructType)result.type;
	auto pt = cast(PointerType)result.type;

	if (strct !is null) {
		makePointer(state, result);
	} else if (pt !is null) {
		makeNonPointer(state, result);

		strct = cast(StructType)pt.base;
		if (strct is null)
			throw CompilerPanic(exp.location, "not a pointer to a struct");

		result.type = strct;
		result.isPointer = true;
	} else {
		throw CompilerPanic(exp.location, "is not a struct");
	}
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

/**
 * Ensures that the given Value is a pointer by allocating temp storage for it.
 */
void makePointer(State state, Value result)
{
	if (result.isPointer)
		return;

	auto v = LLVMBuildAlloca(state.builder, result.type.llvmType, "tempStorage");
	LLVMBuildStore(state.builder, result.value, v);

	result.value = v;
	result.isPointer = true;
}
