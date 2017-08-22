// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.newreplacer;

import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;
import volt.visitor.scopemanager;

import volt.lowerer.alloc;
import volt.lowerer.array;

import volt.semantic.typer;
import volt.semantic.lookup;
import volt.semantic.mangle;
import volt.semantic.classify;
import volt.semantic.overload;

ir.Exp createArrayAlloc(ref in Location loc, LanguagePass lp,
                        ir.Scope baseScope, ir.ArrayType atype, ir.Exp sizeArg)
{
	auto sexp = buildStatementExp(loc);
	auto sizeVar = buildVariableAnonSmart(loc, baseScope, sexp,
		buildSizeT(loc, lp.target), sizeArg);
	auto allocCall = buildAllocTypePtr(loc, lp, atype.base,
		buildExpReference(loc, sizeVar, sizeVar.name));
	auto slice = buildSlice(loc, allocCall,
		buildConstantSizeT(loc, lp.target, 0),
		buildExpReference(loc, sizeVar, sizeVar.name));
	sexp.exp = slice;
	return sexp;
}

ir.StatementExp buildClassConstructionWrapper(ref in Location loc, LanguagePass lp,
                                              ir.Scope current, ir.Class _class,
                                              ir.Function constructor,
                                              ir.Exp[] exps)
{
	auto sexp = new ir.StatementExp();
	sexp.loc = loc;

	// -1
	auto count = buildConstantSizeT(loc, lp.target, size_t.max);

	// auto thisVar = allocDg(_class, -1);
	auto thisVar = buildVariableSmart(loc, _class, ir.Variable.Storage.Function, "thisVar");
	thisVar.assign = buildAllocVoidPtr(loc, lp, _class,  count);
	thisVar.assign = buildCastSmart(loc, _class, thisVar.assign);
	sexp.statements ~= thisVar;
	sexp.exp = buildExpReference(loc, thisVar, "thisVar");

	// thisVar.__ctor(<exps>);
	auto ctor = buildExpReference(loc, constructor, "this");
	auto child = buildExpReference(loc, thisVar, "thisVar");
	auto cdg = buildCreateDelegate(loc, child, ctor);
	buildExpStat(loc, sexp, buildCall(loc, cdg, exps));

	return sexp;
}

class NewReplacer : ScopeManager, Pass
{
public:
	LanguagePass lp;
	ir.Module thisModule;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}
	
	override void transform(ir.Module m)
	{
		thisModule = m;
		accept(m, this);
	}

	override void close()
	{	
	}

	override Status enter(ref ir.Exp exp, ir.Unary unary)
	{
		if (unary.op != ir.Unary.Op.New) {
			return Continue;
		}

		auto rtype = realType(unary.type);
		auto asArray = cast(ir.ArrayType) rtype;
		auto asClass = cast(ir.Class) rtype;

		if (asArray !is null && unary.argumentList.length > 0) {
			if (isIntegral(realType(getExpType(unary.argumentList[0])))) {
				return handleArrayNew(exp, unary, asArray);
			}
			return handleArrayCopy(exp, unary, asArray);
		} else if (asClass !is null && unary.hasArgumentList) {
			return handleClass(exp, unary, asClass);
		}

		return handleOther(exp, unary);
	}

	protected Status handleArrayNew(ref ir.Exp exp, ir.Unary unary, ir.ArrayType array)
	{
		if (unary.argumentList.length != 1) {
			throw panic(unary.loc, "multidimensional arrays unsupported at the moment.");
		}
		auto arg = buildCastSmart(exp.loc, buildSizeT(exp.loc, lp.target), unary.argumentList[0]);
		exp = createArrayAlloc(unary.loc, lp, thisModule.myScope, array, arg);
		return Continue;
	}

	protected Status handleArrayCopy(ref ir.Exp exp, ir.Unary unary, ir.ArrayType array)
	{
		auto loc = unary.loc;
		auto copyFn = getLlvmMemCopy(loc, lp);

		auto statExp = buildStatementExp(loc);

		auto offset = buildVariable(
			loc, buildSizeT(loc, lp.target), ir.Variable.Storage.Function,
			"offset", buildConstantSizeT(loc, lp.target, 0)
		);
		statExp.statements ~= offset;

		ir.Variable[] variables = new ir.Variable[](unary.argumentList.length);
		ir.Exp sizeExp = buildConstantSizeT(loc, lp.target, 0);
		foreach (i, arg; unary.argumentList) {
			auto var = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp, getExpType(arg), arg);
			panicAssert(exp, (cast(ir.ArrayType)realType(var.type)) !is null);
			sizeExp = buildAdd(loc, sizeExp,
				buildArrayLength(loc, lp.target, buildExpReference(loc, var, var.name)));
			variables[i] = var;
		}
		auto newArray = buildVariable(
			loc, copyTypeSmart(loc, array), ir.Variable.Storage.Function,
			"newArray", createArrayAlloc(loc, lp, thisModule.myScope, array, sizeExp)
		);
		statExp.statements ~= newArray;

		foreach (i, arg; unary.argumentList) {
			auto source = variables[i];
			panicAssert(exp, (cast(ir.ArrayType)realType(source.type)) !is null);

			ir.Exp[] args = [
				cast(ir.Exp)
				buildAdd(loc,
					buildCastToVoidPtr(loc, buildArrayPtr(loc, newArray.type,
						buildExpReference(loc, newArray, newArray.name)
					)),
					buildExpReference(loc, offset, offset.name)
				),
				buildCastToVoidPtr(loc, buildArrayPtr(loc, source.type, buildExpReference(loc, source, source.name))),
				buildBinOp(loc, ir.BinOp.Op.Mul,
					buildArrayLength(loc, lp.target, buildExpReference(loc, source, source.name)),
					buildConstantSizeT(loc, lp.target, size(lp.target, array.base))
				),
				buildConstantInt(loc, 0),
				buildConstantFalse(loc)
			];
			buildExpStat(loc, statExp, buildCall(loc, copyFn, args, copyFn.name));

			if (i+1 == unary.argumentList.length) {
				// last iteration, skip advancing the offset.
				continue;
			}

			buildExpStat(loc, statExp,
				buildAssign(loc,
					buildExpReference(loc, offset, offset.name),
					buildAdd(loc,
						buildExpReference(loc, offset, offset.name),
						buildBinOp(loc, ir.BinOp.Op.Mul,
							buildArrayLength(loc, lp.target, buildExpReference(loc, source, source.name)),
							buildConstantSizeT(loc, lp.target, size(lp.target, array.base))
						)
					)
				)
			);
		}

		statExp.exp = buildExpReference(loc, newArray, newArray.name);
		exp = statExp;

		return Continue;
	}

	protected Status handleClass(ref ir.Exp exp, ir.Unary unary, ir.Class clazz)
	{
		assert(unary.ctor !is null);
		exp = buildClassConstructionWrapper(
			unary.loc, lp, current, clazz, unary.ctor,
			unary.argumentList);
		return Continue;
	}

	protected Status handleOther(ref ir.Exp exp, ir.Unary unary)
	{
		exp = buildAllocTypePtr(unary.loc, lp, unary.type);

		return Continue;
	}
}
