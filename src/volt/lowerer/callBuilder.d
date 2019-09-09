/*#D*/
// Copyright 2018, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Build calls to intrinsic functions and the like.
 *
 * These calls can differ based on LLVM version etc, so we want
 * to handle that messiness here.
 */
module volt.lowerer.callBuilder;

import volt.interfaces;
import ir = volta.ir;
import token = volta.ir.location;
import util = volta.util.util;
import semantic = volt.semantic.classify;


//! Call `buildAndAddMemfoo`, wrapping `dst` in an ExpReference.
void buildAndAddMemfoo(ref in token.Location loc,
	ir.BlockStatement bexp, ir.Function memcpyFunction,
	ir.Variable dst, ir.Exp src,
	ir.Exp len, ir.Type base, TargetInfo target)
{
	buildAndAddMemfoo(/*#ref*/loc, bexp, memcpyFunction,
		util.buildExpReference(/*#ref*/loc, dst, dst.name), src,
		len, base, target);
}

/*!
 * Build a call with `buildIntrinsicMemfoo` and add it to a BlockStatement.
 *
 * Alterations performed:
 * - `src` will be cast to a void*.
 * - The length will be determined by `base`'s size times len.
 */
void buildAndAddMemfoo(ref in token.Location loc,
	ir.BlockStatement bexp, ir.Function memcpyFunction,
	ir.Exp dst, ir.Exp src,
	ir.Exp len, ir.Type base, TargetInfo target)
{
	auto baseSize = util.buildConstantSizeT(/*#ref*/loc,
		target, semantic.size(target, base));
	auto theCall = buildIntrinsicMemfoo(/*#ref*/loc,
		memcpyFunction,
		dst, util.buildCastToVoidPtr(/*#ref*/loc, src),
		util.buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
			len, baseSize), target);
	util.buildExpStat(/*#ref*/loc, bexp, theCall);
}

/*!
 * Build a call with `buildIntrinsicMemfoo` and add it to a StatementExp.
 *
 * Alterations performed:
 * - `src` will be cast to a void*.
 * - The length will be determined by `base`'s size times len.
 */
void buildAndAddMemfoo(ref in token.Location loc,
	ir.StatementExp sexp, ir.Function memcpyFunction,
	ir.Exp dst, ir.Exp src,
	ir.Exp len, ir.Type base, TargetInfo target)
{
	auto baseSize = util.buildConstantSizeT(/*#ref*/loc,
		target, semantic.size(target, base));
	auto theCall = buildIntrinsicMemfoo(/*#ref*/loc,
		memcpyFunction,
		dst, util.buildCastToVoidPtr(/*#ref*/loc, src),
		util.buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
			len, baseSize), target);
	util.buildExpStat(/*#ref*/loc, sexp, theCall);
}

/*!
 * Build a call to a memcpy/memmove function, or a function that takes the same arguments.
 *
 * `memcpyFunction` will be wrapped in an ExpReference.  
 * Alignment (if present) will be 0, and volatile will be false.
 */
ir.Exp buildIntrinsicMemfoo(ref in token.Location loc, 
	ir.Function memcpyFunction,
	ir.Exp dst, ir.Exp src, ir.Exp len, TargetInfo target)
{
	ir.Exp[] args;
	if (target.llvmIntrinsicVersion == 2) {
		args = [dst, src, len, util.buildConstantFalse(/*#ref*/loc)];
	} else {
		args = [dst, src, len, util.buildConstantInt(/*#ref*/loc, 0),
			util.buildConstantFalse(/*#ref*/loc)];
	}

	return util.buildCall(/*#ref*/loc,
		util.buildExpReference(/*#ref*/loc, memcpyFunction, memcpyFunction.name),
		args);
}

/*!
 * Build a call to a memset function.
 *
 * `memsetFunction` will be wrapped in an ExpReference.  
 * Alignment (if present) will be 0, and volatile will be false.
 */
ir.Exp buildIntrinsicMemset(ref in token.Location loc,
	ir.Function memsetFunction,
	ir.Exp dst, ir.Exp val, ir.Exp len, TargetInfo target)
{
	ir.Exp[] args;
	if (target.llvmIntrinsicVersion == 2) {
		args = [dst, val, len, util.buildConstantFalse(/*#ref*/loc)];
	} else {
		args = [dst, val, len, util.buildConstantInt(/*#ref*/loc, 0),
			util.buildConstantFalse(/*#ref*/loc)];
	}

	return util.buildCall(/*#ref*/loc,
		util.buildExpReference(/*#ref*/loc, memsetFunction, memsetFunction.name),
		args);
}
