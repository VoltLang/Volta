// Copyright © 2013-2015, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2013-2015, David Herberth.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.array;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.interfaces;
import volt.token.location;

import volt.semantic.util;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.classify;


/*
 *
 * Common helpers.
 *
 */

ir.Function getLlvmMemMove(Location loc, LanguagePass lp)
{
	auto name32 = "__llvm_memmove_p0i8_p0i8_i32";
	auto name64 = "__llvm_memmove_p0i8_p0i8_i64";
	auto name = lp.settings.isVersionSet("V_P64") ? name64 : name32;
	return retrieveFunctionFromObject(lp, loc, name);
}

ir.Function getLlvmMemCopy(Location loc, LanguagePass lp)
{
	auto name32 = "__llvm_memcpy_p0i8_p0i8_i32";
	auto name64 = "__llvm_memcpy_p0i8_p0i8_i64";
	auto name = lp.settings.isVersionSet("V_P64") ? name64 : name32;
	return retrieveFunctionFromObject(lp, loc, name);
}


/*
 *
 * Array function getters.
 *
 */

ir.Function getArrayAppendFunction(Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType ltype, ir.Type rtype, bool isAssignment)
{
	if (ltype.mangledName is null) {
		ltype.mangledName = mangle(ltype);
	}
	if (rtype.mangledName is null) {
		rtype.mangledName = mangle(rtype);
	}

	string name;
	if (isAssignment) {
		name = "__appendArrayAssign" ~ ltype.mangledName ~ rtype.mangledName;
	} else {
		name = "__appendArray" ~ ltype.mangledName ~ rtype.mangledName;
	}

	auto fn = lookupFunction(lp, thisModule.myScope, loc, name);
	if (fn !is null) {
		return fn;
	}

	fn = buildFunction(loc, thisModule.children, thisModule.myScope, name);
	fn.type.ret = copyTypeSmart(loc, ltype);

	ir.FunctionParam left, right;
	if (isAssignment) {
		left = addParam(loc, fn, buildPtrSmart(loc, ltype), "left");
	} else {
		left = addParamSmart(loc, fn, ltype, "left");
	}
	right = addParamSmart(loc, fn, rtype, "right");

	auto fnAlloc = lp.allocDgVariable;
	auto allocExpRef = buildExpReference(loc, fnAlloc, fnAlloc.name);

	auto fnCopy = getLlvmMemCopy(loc, lp);

	ir.Exp[] args;

	auto allocated = buildVarStatSmart(loc, fn._body, fn._body.myScope, buildVoidPtr(loc), "allocated");
	auto count = buildVarStatSmart(loc, fn._body, fn._body.myScope, buildSizeT(loc, lp), "count");

	buildExpStat(loc, fn._body,
		buildAssign(loc,
			buildExpReference(loc, count, count.name),
			buildAdd(loc,
				buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
				buildConstantSizeT(loc, lp, 1)
			)
		)
	);

	args = [
		cast(ir.Exp)
		buildTypeidSmart(loc, ltype.base),
		buildExpReference(loc, count, count.name)
	];

	buildExpStat(loc, fn._body,
		buildAssign(loc,
			buildExpReference(loc, allocated, allocated.name),
			buildCall(loc, allocExpRef, args)
		)
	);

	args = [
		cast(ir.Exp)
		buildExpReference(loc, allocated, allocated.name),
		buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, left, left.name), "ptr")),
		buildBinOp(loc, ir.BinOp.Op.Mul,
			buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
			buildConstantSizeT(loc, lp, size(lp, ltype.base))
		),
		buildConstantInt(loc, 0),
		buildConstantFalse(loc)
	];
	buildExpStat(loc, fn._body, buildCall(loc, buildExpReference(loc, fnCopy, fnCopy.name), args));

	buildExpStat(loc, fn._body,
		buildAssign(loc,
			buildDeref(loc,
				buildAdd(loc,
					buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
					buildAccess(loc, buildExpReference(loc, left, left.name), "length")
				)
			),
			buildExpReference(loc, right, right.name)
		)
	);

	if (isAssignment) {
		buildExpStat(loc, fn._body,
			buildAssign(loc,
				buildDeref(loc, buildExpReference(loc, left, left.name)),
				buildSlice(loc,
					buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
					[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
				)
			)
		);
		buildReturnStat(loc, fn._body, buildDeref(loc, buildExpReference(loc, left, left.name)));
	} else {
		buildReturnStat(loc, fn._body,
			buildSlice(loc,
				buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
				[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
			)
		);
	}

	return fn;
}

ir.Function getArrayPrependFunction(Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType ltype, ir.Type rtype)
{
	if (ltype.mangledName is null) {
		ltype.mangledName = mangle(ltype);
	}
	if (rtype.mangledName is null) {
		rtype.mangledName = mangle(rtype);
	}

	string name = "__prependArray" ~ ltype.mangledName ~ rtype.mangledName;

	auto fn = lookupFunction(lp, thisModule.myScope, loc, name);
	if (fn !is null) {
		return fn;
	}

	fn = buildFunction(loc, thisModule.children, thisModule.myScope, name);
	fn.mangledName = fn.name;
	fn.isWeakLink = true;
	fn.type.ret = copyTypeSmart(loc, ltype);

	ir.FunctionParam left, right;
	right = addParamSmart(loc, fn, rtype, "left");
	left = addParamSmart(loc, fn, ltype, "right");

	auto fnAlloc = lp.allocDgVariable;
	auto allocExpRef = buildExpReference(loc, fnAlloc, fnAlloc.name);

	auto fnCopy = getLlvmMemCopy(loc, lp);

	ir.Exp[] args;

	auto allocated = buildVarStatSmart(loc, fn._body, fn._body.myScope, buildVoidPtr(loc), "allocated");
	auto count = buildVarStatSmart(loc, fn._body, fn._body.myScope, buildSizeT(loc, lp), "count");

	buildExpStat(loc, fn._body,
		buildAssign(loc,
			buildExpReference(loc, count, count.name),
			buildAdd(loc,
				buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
				buildConstantSizeT(loc, lp, 1)
			)
		)
	);

	args = [
		cast(ir.Exp)
		buildTypeidSmart(loc, ltype.base),
		buildExpReference(loc, count, count.name)
	];

	buildExpStat(loc, fn._body,
		buildAssign(loc,
			buildExpReference(loc, allocated, allocated.name),
			buildCall(loc, allocExpRef, args)
		)
	);

	args = [
		cast(ir.Exp)
		buildAdd(loc, buildExpReference(loc, allocated, allocated.name), buildConstantSizeT(loc, lp, size(lp, ltype.base))),
		buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, left, left.name), "ptr")),
		buildBinOp(loc, ir.BinOp.Op.Mul,
			buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
			buildConstantSizeT(loc, lp, size(lp, ltype.base))
		),
		buildConstantInt(loc, 0),
		buildConstantFalse(loc)
	];
	buildExpStat(loc, fn._body, buildCall(loc, buildExpReference(loc, fnCopy, fnCopy.name), args));

	buildExpStat(loc, fn._body,
		buildAssign(loc,
			buildDeref(loc,
					buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
			),
			buildExpReference(loc, right, right.name)
		)
	);

	buildReturnStat(loc, fn._body,
		buildSlice(loc,
			buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
			[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
		)
	);

	return fn;
}

ir.Function getArrayCopyFunction(Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType type)
{
	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}

	auto name = "__copyArray" ~ type.mangledName;
	auto fn = lookupFunction(lp, thisModule.myScope, loc, name);
	if (fn !is null) {
		return fn;
	}

	fn = buildFunction(loc, thisModule.children, thisModule.myScope, name);
	fn.mangledName = fn.name;
	fn.isWeakLink = true;
	fn.type.ret = copyTypeSmart(loc, type);
	auto left = addParamSmart(loc, fn, type, "left");
	auto right = addParamSmart(loc, fn, type, "right");

	auto fnMove = getLlvmMemMove(loc, lp);
	auto expRef = buildExpReference(loc, fnMove, fnMove.name);

	auto typeSize = size(lp, type.base);

	ir.Exp[] args = [
		cast(ir.Exp)
		buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, left, "left"), "ptr")),
		buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, right, "right"), "ptr")),
		buildBinOp(loc, ir.BinOp.Op.Mul,
			buildAccess(loc, buildExpReference(loc, left, "left"), "length"),
			buildConstantSizeT(loc, lp, size(lp, type.base))
			),
		buildConstantInt(loc, 0),
		buildConstantFalse(loc)
	];
	buildExpStat(loc, fn._body, buildCall(loc, expRef, args));

	buildReturnStat(loc, fn._body, buildExpReference(loc, fn.params[0], "left"));

	return fn;
}

ir.Function getArrayConcatFunction(Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType type, bool isAssignment)
{
	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}

	string name;
	if (isAssignment) {
		name = "__concatAssignArray" ~ type.mangledName;
	} else {
		name = "__concatArray" ~ type.mangledName;
	}
	auto fn = lookupFunction(lp, thisModule.myScope, loc, name);

	if (fn !is null) {
		return fn;
	}

	fn = buildFunction(loc, thisModule.children, thisModule.myScope, name);
	fn.mangledName = fn.name;
	fn.isWeakLink = true;
	fn.type.ret = copyTypeSmart(loc, type);

	ir.FunctionParam left;
	if (isAssignment) {
		left = addParam(loc, fn, buildPtrSmart(loc, type), "left");
	} else {
		left = addParamSmart(loc, fn, type, "left");
	}
	auto right = addParamSmart(loc, fn, type, "right");

	auto fnAlloc = lp.allocDgVariable;
	auto allocExpRef = buildExpReference(loc, fnAlloc, fnAlloc.name);

	auto fnCopy = getLlvmMemCopy(loc, lp);

	ir.Exp[] args;

	auto allocated = buildVarStatSmart(loc, fn._body, fn._body.myScope, buildVoidPtr(loc), "allocated");
	auto count = buildVarStatSmart(loc, fn._body, fn._body.myScope, buildSizeT(loc, lp), "count");

	buildExpStat(loc, fn._body,
		buildAssign(loc,
			buildExpReference(loc, count, count.name),
			buildAdd(loc,
				buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
				buildAccess(loc, buildExpReference(loc, right, right.name), "length")
			)
		)
	);

	args = [
		cast(ir.Exp)
		buildTypeidSmart(loc, type.base),
		buildExpReference(loc, count, count.name)
	];

	buildExpStat(loc, fn._body,
		buildAssign(loc,
			buildExpReference(loc, allocated, allocated.name),
			buildCall(loc, allocExpRef, args)
		)
	);

	args = [
		cast(ir.Exp)
		buildExpReference(loc, allocated, allocated.name),
		buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, left, left.name), "ptr")),
		buildBinOp(loc, ir.BinOp.Op.Mul,
			buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
			buildConstantSizeT(loc, lp, size(lp, type.base))
		),
		buildConstantInt(loc, 0),
		buildConstantFalse(loc)
	];
	buildExpStat(loc, fn._body, buildCall(loc, buildExpReference(loc, fnCopy, fnCopy.name), args));


	args = [
		cast(ir.Exp)
		buildAdd(loc,
			buildExpReference(loc, allocated, allocated.name),
			buildBinOp(loc, ir.BinOp.Op.Mul,
				buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
				buildConstantSizeT(loc, lp, size(lp, type.base))
			)
		),
		buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, right, right.name), "ptr")),
		buildBinOp(loc, ir.BinOp.Op.Mul,
			buildAccess(loc, buildExpReference(loc, right, right.name), "length"),
			buildConstantSizeT(loc, lp, size(lp, type.base))
		),
		buildConstantInt(loc, 0),
		buildConstantFalse(loc)
	];
	buildExpStat(loc, fn._body, buildCall(loc, buildExpReference(loc, fnCopy, fnCopy.name), args));


	if (isAssignment) {
		buildExpStat(loc, fn._body,
			buildAssign(loc,
				buildDeref(loc, buildExpReference(loc, left, left.name)),
				buildSlice(loc,
					buildCastSmart(loc, buildPtrSmart(loc, type.base), buildExpReference(loc, allocated, allocated.name)),
					[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
				)
			)
		);
		buildReturnStat(loc, fn._body, buildDeref(loc, buildExpReference(loc, left, left.name)));
	} else {
		buildReturnStat(loc, fn._body,
			buildSlice(loc,
				buildCastSmart(loc, buildPtrSmart(loc, type.base), buildExpReference(loc, allocated, allocated.name)),
				[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
			)
		);
	}

	return fn;
}

ir.Function getArrayCmpFunction(Location loc, LanguagePass lp, ir.Module thisModule, ir.ArrayType type, bool notEqual)
{
	if (type.mangledName is null) {
		type.mangledName = mangle(type);
	}

	string name;
	if (notEqual) {
		name = "__cmpNotArray" ~ type.mangledName;
	} else {
		name = "__cmpArray" ~ type.mangledName;
	}
	auto fn = lookupFunction(lp, thisModule.myScope, loc, name);
	if (fn !is null) {
		return fn;
	}

	fn = buildFunction(loc, thisModule.children, thisModule.myScope, name);
	fn.mangledName = fn.name;
	fn.isWeakLink = true;
	fn.type.ret = buildBool(loc);

	auto left = addParamSmart(loc, fn, type, "left");
	auto right = addParamSmart(loc, fn, type, "right");

	auto memCmp = lp.memcmpFunc;
	auto memCmpExpRef = buildExpReference(loc, memCmp, memCmp.name);


	auto thenState = buildBlockStat(loc, fn, fn._body.myScope);
	buildReturnStat(loc, thenState, buildConstantBool(loc, notEqual));
	buildIfStat(loc, fn._body,
		buildBinOp(loc, ir.BinOp.Op.NotEqual,
			buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
			buildAccess(loc, buildExpReference(loc, right, right.name), "length")
		),
		thenState
	);

	buildReturnStat(loc, fn._body,
		buildBinOp(loc, notEqual ? ir.BinOp.Op.NotEqual : ir.BinOp.Op.Equal,
			buildCall(loc, memCmpExpRef, [
				buildCastSmart(loc, buildVoidPtr(loc), buildAccess(loc, buildExpReference(loc, left, left.name), "ptr")),
				buildCastSmart(loc, buildVoidPtr(loc), buildAccess(loc, buildExpReference(loc, right, right.name), "ptr")),
				cast(ir.Exp)buildBinOp(loc, ir.BinOp.Op.Mul,
					buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
					buildConstantSizeT(loc, lp, size(lp, type.base))
				)

			]),
			buildConstantInt(loc, 0)
		)
	);

	return fn;
}