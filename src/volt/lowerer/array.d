/*#D*/
// Copyright © 2013-2015, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2013-2015, David Herberth.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.array;

import watt.text.format : format;

import ir = volta.ir;
import volta.util.copy;
import volta.util.util;

import volt.interfaces;
import volta.ir.location;

import volt.semantic.util;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.classify;

import volt.lowerer.alloc : buildAllocVoidPtr;


/*
 *
 * Common helpers.
 *
 */

ir.Function getLlvmMemMove(ref in Location loc, LanguagePass lp)
{
	return lp.ver.isP64 ? lp.llvmMemmove64 : lp.llvmMemmove32;
}

ir.Function getLlvmMemCopy(ref in Location loc, LanguagePass lp)
{
	return lp.ver.isP64 ? lp.llvmMemcpy64 : lp.llvmMemcpy32;
}


/*
 *
 * Array function getters.
 *
 */

ir.Function getArrayAppendFunction(ref in Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType ltype, ir.Type rtype, bool isAssignment)
{
	if (ltype.mangledName is null) {
		ltype.mangledName = mangle(ltype);
	}
	if (rtype.mangledName is null) {
		rtype.mangledName = mangle(rtype);
	}

	string name;
	if (isAssignment) {
		name = format("__appendArrayAssign%s%s", ltype.mangledName, rtype.mangledName);
	} else {
		name = format("__appendArray%s%s", ltype.mangledName, rtype.mangledName);
	}

	auto func = lookupFunction(lp, thisModule.myScope, /*#ref*/loc, name);
	if (func !is null) {
		return func;
	}

	func = buildFunction(lp.errSink, /*#ref*/loc, thisModule.children, thisModule.myScope, name);
	func.type.ret = copyTypeSmart(/*#ref*/loc, ltype);

	ir.FunctionParam left, right;
	if (isAssignment) {
		left = addParam(lp.errSink, /*#ref*/loc, func, buildPtrSmart(/*#ref*/loc, ltype), "left");
	} else {
		left = addParamSmart(lp.errSink, /*#ref*/loc, func, ltype, "left");
	}
	right = addParamSmart(lp.errSink, /*#ref*/loc, func, rtype, "right");

	auto funcCopy = getLlvmMemCopy(/*#ref*/loc, lp);

	ir.Exp[] args;

	auto allocated = buildVarStatSmart(lp.errSink, /*#ref*/loc, func.parsedBody, func.parsedBody.myScope, buildVoidPtr(/*#ref*/loc), "allocated");
	auto count = buildVarStatSmart(lp.errSink, /*#ref*/loc, func.parsedBody, func.parsedBody.myScope, buildSizeT(/*#ref*/loc, lp.target), "count");
	ir.Exp leftlength()
	{
		if (isAssignment) {
			return buildArrayLength(/*#ref*/loc, lp.target, buildDeref(/*#ref*/loc, buildExpReference(/*#ref*/loc, left, left.name)));
		} else {
			return buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, left, left.name));
		}
	}

	buildExpStat(/*#ref*/loc, func.parsedBody,
		buildAssign(/*#ref*/loc,
			buildExpReference(/*#ref*/loc, count, count.name),
			buildAdd(/*#ref*/loc,
				leftlength(),
				buildConstantSizeT(/*#ref*/loc, lp.target, 1)
			)
		)
	);

	buildExpStat(/*#ref*/loc, func.parsedBody,
		buildAssign(/*#ref*/loc,
			buildExpReference(/*#ref*/loc, allocated, allocated.name),
			buildAllocVoidPtr(/*#ref*/loc, lp, ltype.base, buildExpReference(/*#ref*/loc, count, count.name))
		)
	);

	ir.Exp leftPtr;
	if (isAssignment) {
		leftPtr = buildArrayPtr(/*#ref*/loc, left.type, buildDeref(/*#ref*/loc, buildExpReference(/*#ref*/loc, left, left.name)));
	} else {
		leftPtr = buildArrayPtr(/*#ref*/loc, left.type, buildExpReference(/*#ref*/loc, left, left.name));
	}

	args = [
		cast(ir.Exp)
		buildExpReference(/*#ref*/loc, allocated, allocated.name),
		buildCastToVoidPtr(/*#ref*/loc, leftPtr),
		buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
			leftlength(),
			buildConstantSizeT(/*#ref*/loc, lp.target, size(lp.target, ltype.base))
		),
		buildConstantInt(/*#ref*/loc, 0),
		buildConstantFalse(/*#ref*/loc)
	];
	buildExpStat(/*#ref*/loc, func.parsedBody, buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, funcCopy, funcCopy.name), args));

	buildExpStat(/*#ref*/loc, func.parsedBody,
		buildAssign(/*#ref*/loc,
			buildDeref(/*#ref*/loc,
				buildAdd(/*#ref*/loc,
					buildCastSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, ltype.base), buildExpReference(/*#ref*/loc, allocated, allocated.name)),
					leftlength()
				)
			),
			buildExpReference(/*#ref*/loc, right, right.name)
		)
	);

	if (isAssignment) {
		buildExpStat(/*#ref*/loc, func.parsedBody,
			buildAssign(/*#ref*/loc,
				buildDeref(/*#ref*/loc, buildExpReference(/*#ref*/loc, left, left.name)),
				buildSlice(/*#ref*/loc,
					buildCastSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, ltype.base), buildExpReference(/*#ref*/loc, allocated, allocated.name)),
					[cast(ir.Exp)buildConstantSizeT(/*#ref*/loc, lp.target, 0),
						buildExpReference(/*#ref*/loc, count, count.name)]
				)
			)
		);
		buildReturnStat(/*#ref*/loc, func.parsedBody, buildDeref(/*#ref*/loc, buildExpReference(/*#ref*/loc, left, left.name)));
	} else {
		buildReturnStat(/*#ref*/loc, func.parsedBody,
			buildSlice(/*#ref*/loc,
				buildCastSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, ltype.base), buildExpReference(/*#ref*/loc, allocated, allocated.name)),
				[cast(ir.Exp)buildConstantSizeT(/*#ref*/loc, lp.target, 0),
					buildExpReference(/*#ref*/loc, count, count.name)]
			)
		);
	}

	return func;
}

ir.Function getArrayPrependFunction(ref in Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType ltype, ir.Type rtype)
{
	if (ltype.mangledName is null) {
		ltype.mangledName = mangle(ltype);
	}
	if (rtype.mangledName is null) {
		rtype.mangledName = mangle(rtype);
	}

	string name = format("__prependArray%s%s", ltype.mangledName, rtype.mangledName);

	auto func = lookupFunction(lp, thisModule.myScope, /*#ref*/loc, name);
	if (func !is null) {
		return func;
	}

	func = buildFunction(lp.errSink, /*#ref*/loc, thisModule.children, thisModule.myScope, name);
	func.mangledName = func.name;
	func.isMergable = true;
	func.type.ret = copyTypeSmart(/*#ref*/loc, ltype);

	ir.FunctionParam left, right;
	right = addParamSmart(lp.errSink, /*#ref*/loc, func, rtype, "left");
	left = addParamSmart(lp.errSink, /*#ref*/loc, func, ltype, "right");

	auto funcCopy = getLlvmMemCopy(/*#ref*/loc, lp);

	ir.Exp[] args;

	auto allocated = buildVarStatSmart(lp.errSink, /*#ref*/loc, func.parsedBody, func.parsedBody.myScope, buildVoidPtr(/*#ref*/loc), "allocated");
	auto count = buildVarStatSmart(lp.errSink, /*#ref*/loc, func.parsedBody, func.parsedBody.myScope, buildSizeT(/*#ref*/loc, lp.target), "count");

	buildExpStat(/*#ref*/loc, func.parsedBody,
		buildAssign(/*#ref*/loc,
			buildExpReference(/*#ref*/loc, count, count.name),
			buildAdd(/*#ref*/loc,
				buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, left, left.name)),
				buildConstantSizeT(/*#ref*/loc, lp.target, 1)
			)
		)
	);

	buildExpStat(/*#ref*/loc, func.parsedBody,
		buildAssign(/*#ref*/loc,
			buildExpReference(/*#ref*/loc, allocated, allocated.name),
			buildAllocVoidPtr(/*#ref*/loc, lp, ltype.base, buildExpReference(/*#ref*/loc, count, count.name))
		)
	);

	args = [
		cast(ir.Exp)
		buildAdd(/*#ref*/loc, buildExpReference(/*#ref*/loc, allocated, allocated.name),
			buildConstantSizeT(/*#ref*/loc, lp.target, size(lp.target, ltype.base))),
		buildCastToVoidPtr(/*#ref*/loc, buildArrayPtr(/*#ref*/loc, left.type, buildExpReference(/*#ref*/loc, left, left.name))),
		buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
			buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, left, left.name)),
			buildConstantSizeT(/*#ref*/loc, lp.target, size(lp.target, ltype.base))
		),
		buildConstantInt(/*#ref*/loc, 0),
		buildConstantFalse(/*#ref*/loc)
	];
	buildExpStat(/*#ref*/loc, func.parsedBody, buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, funcCopy, funcCopy.name), args));

	buildExpStat(/*#ref*/loc, func.parsedBody,
		buildAssign(/*#ref*/loc,
			buildDeref(/*#ref*/loc,
					buildCastSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, ltype.base), buildExpReference(/*#ref*/loc, allocated, allocated.name))
			),
			buildExpReference(/*#ref*/loc, right, right.name)
		)
	);

	buildReturnStat(/*#ref*/loc, func.parsedBody,
		buildSlice(/*#ref*/loc,
			buildCastSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, ltype.base), buildExpReference(/*#ref*/loc, allocated, allocated.name)),
			[cast(ir.Exp)buildConstantSizeT(/*#ref*/loc, lp.target, 0), buildExpReference(/*#ref*/loc, count, count.name)]
		)
	);

	return func;
}

ir.Function getArrayCopyFunction(ref in Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType type)
{
	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}

	auto name = format("__copyArray%s", type.mangledName);
	auto func = lookupFunction(lp, thisModule.myScope, /*#ref*/loc, name);
	if (func !is null) {
		return func;
	}

	func = buildFunction(lp.errSink, /*#ref*/loc, thisModule.children, thisModule.myScope, name);
	func.mangledName = func.name;
	func.isMergable = true;
	func.type.ret = copyTypeSmart(/*#ref*/loc, type);
	auto left = addParamSmart(lp.errSink, /*#ref*/loc, func, type, "left");
	auto right = addParamSmart(lp.errSink, /*#ref*/loc, func, type, "right");

	auto funcMove = getLlvmMemMove(/*#ref*/loc, lp);
	auto expRef = buildExpReference(/*#ref*/loc, funcMove, funcMove.name);

	auto typeSize = size(lp.target, type.base);

	ir.Exp[] args = [
		cast(ir.Exp)
		buildCastToVoidPtr(/*#ref*/loc, buildArrayPtr(/*#ref*/loc, left.type, buildExpReference(/*#ref*/loc, left, "left"))),
		buildCastToVoidPtr(/*#ref*/loc, buildArrayPtr(/*#ref*/loc, right.type, buildExpReference(/*#ref*/loc, right, "right"))),
		buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
			buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, left, "left")),
			buildConstantSizeT(/*#ref*/loc, lp.target, size(lp.target, type.base))
			),
		buildConstantInt(/*#ref*/loc, 0),
		buildConstantFalse(/*#ref*/loc)
	];
	buildExpStat(/*#ref*/loc, func.parsedBody, buildCall(/*#ref*/loc, expRef, args));

	buildReturnStat(/*#ref*/loc, func.parsedBody, buildExpReference(/*#ref*/loc, func.params[0], "left"));

	return func;
}

ir.Function getArrayConcatFunction(ref in Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType type, bool isAssignment)
{
	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}

	string name;
	if (isAssignment) {
		name = format("__concatAssignArray%s", type.mangledName);
	} else {
		name = format("__concatArray%s", type.mangledName);
	}
	auto func = lookupFunction(lp, thisModule.myScope, /*#ref*/loc, name);

	if (func !is null) {
		return func;
	}

	func = buildFunction(lp.errSink, /*#ref*/loc, thisModule.children, thisModule.myScope, name);
	func.mangledName = func.name;
	func.isMergable = true;
	func.type.ret = copyTypeSmart(/*#ref*/loc, type);

	ir.FunctionParam left;
	if (isAssignment) {
		left = addParam(lp.errSink, /*#ref*/loc, func, buildPtrSmart(/*#ref*/loc, type), "left");
	} else {
		left = addParamSmart(lp.errSink, /*#ref*/loc, func, type, "left");
	}
	auto right = addParamSmart(lp.errSink, /*#ref*/loc, func, type, "right");

	auto funcCopy = getLlvmMemCopy(/*#ref*/loc, lp);

	ir.Exp[] args;

	auto allocated = buildVarStatSmart(lp.errSink, /*#ref*/loc, func.parsedBody, func.parsedBody.myScope, buildVoidPtr(/*#ref*/loc), "allocated");
	auto count = buildVarStatSmart(lp.errSink, /*#ref*/loc, func.parsedBody, func.parsedBody.myScope,
		buildSizeT(/*#ref*/loc, lp.target), "count");
	ir.Exp leftlength()
	{
		if (isAssignment) {
			return buildArrayLength(/*#ref*/loc, lp.target, buildDeref(/*#ref*/loc, buildExpReference(/*#ref*/loc, left, left.name)));
		} else {
			return buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, left, left.name));
		}
	}

	buildExpStat(/*#ref*/loc, func.parsedBody,
		buildAssign(/*#ref*/loc,
			buildExpReference(/*#ref*/loc, count, count.name),
			buildAdd(/*#ref*/loc,
				leftlength(),
				buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, right, right.name))
			)
		)
	);

	buildExpStat(/*#ref*/loc, func.parsedBody,
		buildAssign(/*#ref*/loc,
			buildExpReference(/*#ref*/loc, allocated, allocated.name),
			buildAllocVoidPtr(/*#ref*/loc, lp, type.base, buildExpReference(/*#ref*/loc, count, count.name))
		)
	);

	ir.Exp leftPtr;
	if (isAssignment) {
		leftPtr = buildArrayPtr(/*#ref*/loc, left.type, buildDeref(/*#ref*/loc, buildExpReference(/*#ref*/loc, left, left.name)));
	} else {
		leftPtr = buildArrayPtr(/*#ref*/loc, left.type, buildExpReference(/*#ref*/loc, left, left.name));
	}

	args = [
		cast(ir.Exp)
		buildExpReference(/*#ref*/loc, allocated, allocated.name),
		buildCastToVoidPtr(/*#ref*/loc, leftPtr),
		buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
			leftlength(),
			buildConstantSizeT(/*#ref*/loc, lp.target, size(lp.target, type.base))
		),
		buildConstantInt(/*#ref*/loc, 0),
		buildConstantFalse(/*#ref*/loc)
	];
	buildExpStat(/*#ref*/loc, func.parsedBody, buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, funcCopy, funcCopy.name), args));


	args = [
		cast(ir.Exp)
		buildAdd(/*#ref*/loc,
			buildExpReference(/*#ref*/loc, allocated, allocated.name),
			buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
				leftlength(),
				buildConstantSizeT(/*#ref*/loc, lp.target, size(lp.target, type.base))
			)
		),
		buildCastToVoidPtr(/*#ref*/loc, buildArrayPtr(/*#ref*/loc, right.type, buildExpReference(/*#ref*/loc, right, right.name))),
		buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
			buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, right, right.name)),
			buildConstantSizeT(/*#ref*/loc, lp.target, size(lp.target, type.base))
		),
		buildConstantInt(/*#ref*/loc, 0),
		buildConstantFalse(/*#ref*/loc)
	];
	buildExpStat(/*#ref*/loc, func.parsedBody, buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, funcCopy, funcCopy.name), args));


	if (isAssignment) {
		buildExpStat(/*#ref*/loc, func.parsedBody,
			buildAssign(/*#ref*/loc,
				buildDeref(/*#ref*/loc, buildExpReference(/*#ref*/loc, left, left.name)),
				buildSlice(/*#ref*/loc,
					buildCastSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, type.base), buildExpReference(/*#ref*/loc, allocated, allocated.name)),
					[cast(ir.Exp)buildConstantSizeT(/*#ref*/loc, lp.target, 0),
						buildExpReference(/*#ref*/loc, count, count.name)]
				)
			)
		);
		buildReturnStat(/*#ref*/loc, func.parsedBody, buildDeref(/*#ref*/loc, buildExpReference(/*#ref*/loc, left, left.name)));
	} else {
		buildReturnStat(/*#ref*/loc, func.parsedBody,
			buildSlice(/*#ref*/loc,
				buildCastSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, type.base), buildExpReference(/*#ref*/loc, allocated, allocated.name)),
				[cast(ir.Exp)buildConstantSizeT(/*#ref*/loc, lp.target, 0),
					buildExpReference(/*#ref*/loc, count, count.name)]
			)
		);
	}

	return func;
}

ir.Function getArrayCmpFunction(ref in Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType type)
{
	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}

	auto name = format("__cmpArray%s", type.mangledName);
	auto func = lookupFunction(lp, thisModule.myScope, /*#ref*/loc, name);
	if (func !is null) {
		return func;
	}

	func = buildFunction(lp.errSink, /*#ref*/loc, thisModule.children, thisModule.myScope, name);
	func.mangledName = func.name;
	func.isMergable = true;
	func.type.ret = buildInt(/*#ref*/loc);

	auto left = addParamSmart(lp.errSink, /*#ref*/loc, func, type, "left");
	auto right = addParamSmart(lp.errSink, /*#ref*/loc, func, type, "right");

	ir.ExpReference lRef()
	{
		// left
		return buildExpReference(/*#ref*/loc, left, left.name);
	}
	ir.ExpReference rRef()
	{
		// right
		return buildExpReference(/*#ref*/loc, right, right.name);
	}
	ir.BinOp cmp(ir.Exp l, ir.BinOp.Op op, ir.Exp r)
	{
		return buildBinOp(/*#ref*/loc, op, l, r);
	}
	ir.BuiltinExp len(ir.ExpReference eref)
	{
		return buildArrayLength(/*#ref*/loc, lp.target, eref);
	}

	auto memCmp = lp.memcmpFunc;
	auto memCmpExpRef = buildExpReference(/*#ref*/loc, memCmp, memCmp.name);

	auto childArray = cast(ir.ArrayType) type.base;
	if (childArray !is null) {
		/* for (size_t i = 0; i < left.length; ++i) {
		 *     if (i >= right.length || left[i] > right[i]) {
		 *         return 1;
		 *     }
		 *     if (left[i] < right[i]) {
		 *         return -1;
		 *     }
		 * }
		 * if (left.length == right.length) {
		 *     return 0;
		 * }
		 * if (left.length > right.length) {
		 *     return 1;
		 * }
		 * return -1;
		 */
		ir.ForStatement forLoop;
		ir.Variable iVar;

		ir.ExpReference iRef()
		{
			// i
			return buildExpReference(/*#ref*/loc, iVar, iVar.name);
		}

		buildForStatement(/*#ref*/loc, lp.target, func.parsedBody.myScope,
			buildArrayLength(/*#ref*/loc, lp.target, lRef()), /*#out*/forLoop, /*#out*/iVar);

		ir.Postfix lIndex()
		{
			// left[i]
			return buildIndex(/*#ref*/loc, lRef(), iRef());
		}
		ir.Postfix rIndex()
		{
			// right[i]
			return buildIndex(/*#ref*/loc, rRef(), iRef());
		}
		ir.BinOp lrCmp(ir.BinOp.Op op)
		{
			// left[i] op right[i]
			return buildBinOp(/*#ref*/loc, op, lIndex(), rIndex());
		}
		ir.BinOp greaterEqualCmp(ir.Exp lExp, ir.Exp rExp)
		{
			return buildBinOp(/*#ref*/loc, ir.BinOp.Op.GreaterEqual, lExp, rExp);
		}
		ir.BinOp orCmp(ir.Exp lExp, ir.Exp rExp)
		{
			return buildBinOp(/*#ref*/loc, ir.BinOp.Op.OrOr, lExp, rExp);
		}
		ir.BlockStatement returnConstantInteger(int i)
		{
			// { return <i>; }
			auto bs = buildBlockStat(/*#ref*/loc, null, forLoop.block.myScope);
			buildReturnStat(/*#ref*/loc, bs, buildConstantInt(/*#ref*/loc, i));
			return bs;
		}

		auto lengthCheck= greaterEqualCmp(iRef(), buildArrayLength(/*#ref*/loc, lp.target, rRef()));
		auto greaterCmp = orCmp(lengthCheck, lrCmp(ir.BinOp.Op.Greater));
		auto ifThen     = returnConstantInteger(1);
		auto ifs        = buildIfStat(/*#ref*/loc, greaterCmp, ifThen);
		forLoop.block.statements ~= ifs;

		auto lessCmp    = lrCmp(ir.BinOp.Op.Less);
		auto elseThen   = returnConstantInteger(-1);
		auto elseIf     = buildIfStat(/*#ref*/loc, lessCmp, elseThen);
		forLoop.block.statements ~= elseIf;

		func.parsedBody.statements ~= forLoop;

		auto lLength   = buildArrayLength(/*#ref*/loc, lp.target, lRef());
		auto rLength   = buildArrayLength(/*#ref*/loc, lp.target, rRef());
		auto lengthCmp = buildBinOp(/*#ref*/loc, ir.BinOp.Op.Equal, lLength, rLength);
		auto lengthBs  = buildBlockStat(/*#ref*/loc, null, func.parsedBody.myScope);
		buildReturnStat(/*#ref*/loc, lengthBs, buildConstantInt(/*#ref*/loc, 0));
		auto lengthIf  = buildIfStat(/*#ref*/loc, lengthCmp, lengthBs);
		func.parsedBody.statements ~= lengthIf;

		auto leftLongerCmp = cmp(len(lRef()), ir.BinOp.Op.Greater, len(rRef()));
		auto leftLongerBs  = buildBlockStat(/*#ref*/loc, null, func.parsedBody.myScope);
		buildReturnStat(/*#ref*/loc, leftLongerBs, buildConstantInt(/*#ref*/loc, 1));
		auto leftLongerIf  = buildIfStat(/*#ref*/loc, leftLongerCmp, leftLongerBs);
		func.parsedBody.statements ~= leftLongerIf;

		buildReturnStat(/*#ref*/loc, func.parsedBody, buildConstantInt(/*#ref*/loc, -1));
	} else {
		/* len := left.length;
		 * if (right.length < left.length) {
		 *     len = right.length;
		 * }
		 * val := memcmp(left.ptr, right.ptr, len * left.base.size);
		 * if (val != 0 || left.length == right.length) {
		 *     return val;
		 * }
		 * if (left.length < right.length) {
		 *     return -1;
		 * }
		 * return 1;
		 */
		auto lenType = buildSizeT(/*#ref*/loc, lp.target);
		auto lenVar  = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, func.parsedBody, null, lenType, len(lRef()));

		auto rightShorterCmp = cmp(len(rRef()), ir.BinOp.Op.Less, len(lRef()));
		auto rightShorterBs  = buildBlockStat(/*#ref*/loc, null, func.parsedBody.myScope);
		buildExpStat(/*#ref*/loc, rightShorterBs, buildAssign(/*#ref*/loc, lenVar, len(rRef())));
		auto rightShorterIf  = buildIfStat(/*#ref*/loc, rightShorterCmp, rightShorterBs);
		func.parsedBody.statements ~= rightShorterIf;

		auto valType = buildInt(/*#ref*/loc);
		auto valVar  = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, func.parsedBody, null, valType,
			buildCall(/*#ref*/loc, memCmpExpRef, [
				buildCastSmart(/*#ref*/loc, buildVoidPtr(/*#ref*/loc), buildArrayPtr(/*#ref*/loc, left.type, lRef())),
				buildCastSmart(/*#ref*/loc, buildVoidPtr(/*#ref*/loc), buildArrayPtr(/*#ref*/loc, right.type, rRef())),
				cast(ir.Exp)buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
					buildExpReference(/*#ref*/loc, lenVar, lenVar.name),
					buildConstantSizeT(/*#ref*/loc, lp.target, size(lp.target, type.base))
				)
			])
		);

		auto vRef = buildExpReference(/*#ref*/loc, valVar, valVar.name);
		auto zero = buildConstantInt(/*#ref*/loc, 0);
		auto canReturnValCmp = cmp(vRef, ir.BinOp.Op.NotEqual, zero);
		canReturnValCmp = cmp(canReturnValCmp, ir.BinOp.Op.OrOr, cmp(len(lRef()), ir.BinOp.Op.Equal, len(rRef())));
		auto canReturnValBs  = buildBlockStat(/*#ref*/loc, null, func.parsedBody.myScope);
		buildReturnStat(/*#ref*/loc, canReturnValBs, buildExpReference(/*#ref*/loc, valVar, valVar.name));
		auto canReturnValIf  = buildIfStat(/*#ref*/loc, canReturnValCmp, canReturnValBs);
		func.parsedBody.statements ~= canReturnValIf;

		auto leftIsShorterCmp = cmp(len(lRef()), ir.BinOp.Op.Less, len(rRef()));
		auto leftIsShorterBs  = buildBlockStat(/*#ref*/loc, null, func.parsedBody.myScope);
		buildReturnStat(/*#ref*/loc, leftIsShorterBs, buildConstantInt(/*#ref*/loc, -1));
		auto leftIsShorterIf  = buildIfStat(/*#ref*/loc, leftIsShorterCmp, leftIsShorterBs);
		func.parsedBody.statements ~= leftIsShorterIf;

		buildReturnStat(/*#ref*/loc, func.parsedBody, buildConstantInt(/*#ref*/loc, 1));
	}

	return func;
}
