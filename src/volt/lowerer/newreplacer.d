/*#D*/
// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.newreplacer;

import watt.text.format : format;

import ir = volta.ir;
import volta.util.util;
import volta.util.copy;

import volt.errors;
import volt.interfaces;
import volta.ir.location;
import volta.visitor.visitor;
import volta.visitor.scopemanager;

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
	auto sexp = buildStatementExp(/*#ref*/loc);
	auto sizeVar = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, baseScope, sexp,
		buildSizeT(/*#ref*/loc, lp.target), sizeArg);
	auto allocCall = buildAllocTypePtr(/*#ref*/loc, lp, atype.base,
		buildExpReference(/*#ref*/loc, sizeVar, sizeVar.name));
	auto slice = buildSlice(/*#ref*/loc, allocCall,
		buildConstantSizeT(/*#ref*/loc, lp.target, 0),
		buildExpReference(/*#ref*/loc, sizeVar, sizeVar.name));
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
	auto count = buildConstantSizeT(/*#ref*/loc, lp.target, size_t.max);

	// auto thisVar = allocDg(_class, -1);
	auto thisVar = buildVariableSmart(/*#ref*/loc, _class, ir.Variable.Storage.Function, "thisVar");
	thisVar.assign = buildAllocVoidPtr(/*#ref*/loc, lp, _class,  count);
	thisVar.assign = buildCastSmart(/*#ref*/loc, _class, thisVar.assign);
	sexp.statements ~= thisVar;
	sexp.exp = buildExpReference(/*#ref*/loc, thisVar, "thisVar");

	// thisVar.__ctor(<exps>);
	auto ctor = buildExpReference(/*#ref*/loc, constructor, "this");
	auto child = buildExpReference(/*#ref*/loc, thisVar, "thisVar");
	auto cdg = buildCreateDelegate(/*#ref*/loc, child, ctor);
	buildExpStat(/*#ref*/loc, sexp, buildCall(/*#ref*/loc, cdg, exps));

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
		super(lp.errSink);
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
				return handleArrayNew(/*#ref*/exp, unary, asArray);
			}
			return handleArrayCopy(/*#ref*/exp, unary, asArray);
		} else if (asClass !is null && unary.hasArgumentList) {
			return handleClass(/*#ref*/exp, unary, asClass);
		}

		return handleOther(/*#ref*/exp, unary);
	}

	protected Status handleArrayNew(ref ir.Exp exp, ir.Unary unary, ir.ArrayType array)
	{
		if (unary.argumentList.length != 1) {
			throw panic(/*#ref*/unary.loc, "multidimensional arrays unsupported at the moment.");
		}
		auto arg = buildCastSmart(/*#ref*/exp.loc, buildSizeT(/*#ref*/exp.loc, lp.target), unary.argumentList[0]);
		exp = createArrayAlloc(/*#ref*/unary.loc, lp, thisModule.myScope, array, arg);
		return Continue;
	}

	protected Status handleArrayCopy(ref ir.Exp exp, ir.Unary unary, ir.ArrayType array)
	{
		auto loc = unary.loc;
		auto copyFn = getLlvmMemCopy(/*#ref*/loc, lp);

		auto statExp = buildStatementExp(/*#ref*/loc);

		auto offset = buildVariable(
			/*#ref*/loc, buildSizeT(/*#ref*/loc, lp.target), ir.Variable.Storage.Function,
			"offset", buildConstantSizeT(/*#ref*/loc, lp.target, 0)
		);
		statExp.statements ~= offset;

		ir.Variable[] variables = new ir.Variable[](unary.argumentList.length);
		ir.Exp sizeExp = buildConstantSizeT(/*#ref*/loc, lp.target, 0);
		foreach (i, arg; unary.argumentList) {
			auto var = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, cast(ir.BlockStatement)current.node, statExp, getExpType(arg), arg);
			panicAssert(exp, (cast(ir.ArrayType)realType(var.type)) !is null);
			sizeExp = buildAdd(/*#ref*/loc, sizeExp,
				buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, var, var.name)));
			variables[i] = var;
		}
		auto newArray = buildVariable(
			/*#ref*/loc, copyTypeSmart(/*#ref*/loc, array), ir.Variable.Storage.Function,
			"newArray", createArrayAlloc(/*#ref*/loc, lp, thisModule.myScope, array, sizeExp)
		);
		statExp.statements ~= newArray;

		foreach (i, arg; unary.argumentList) {
			auto source = variables[i];
			panicAssert(exp, (cast(ir.ArrayType)realType(source.type)) !is null);

			ir.Exp[] args = [
				cast(ir.Exp)
				buildAdd(/*#ref*/loc,
					buildCastToVoidPtr(/*#ref*/loc, buildArrayPtr(/*#ref*/loc, newArray.type,
						buildExpReference(/*#ref*/loc, newArray, newArray.name)
					)),
					buildExpReference(/*#ref*/loc, offset, offset.name)
				),
				buildCastToVoidPtr(/*#ref*/loc, buildArrayPtr(/*#ref*/loc, source.type,
					buildExpReference(/*#ref*/loc, source, source.name))),
				buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
					buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, source, source.name)),
					buildConstantSizeT(/*#ref*/loc, lp.target, size(lp.target, array.base))
				),
				buildConstantInt(/*#ref*/loc, 0),
				buildConstantFalse(/*#ref*/loc)
			];
			buildExpStat(/*#ref*/loc, statExp, buildCall(/*#ref*/loc, copyFn, args, copyFn.name));

			if (i+1 == unary.argumentList.length) {
				// last iteration, skip advancing the offset.
				continue;
			}

			buildExpStat(/*#ref*/loc, statExp,
				buildAssign(/*#ref*/loc,
					buildExpReference(/*#ref*/loc, offset, offset.name),
					buildAdd(/*#ref*/loc,
						buildExpReference(/*#ref*/loc, offset, offset.name),
						buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
							buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, source, source.name)),
							buildConstantSizeT(/*#ref*/loc, lp.target, size(lp.target, array.base))
						)
					)
				)
			);
		}

		statExp.exp = buildExpReference(/*#ref*/loc, newArray, newArray.name);
		exp = statExp;

		return Continue;
	}

	protected Status handleClass(ref ir.Exp exp, ir.Unary unary, ir.Class clazz)
	{
		assert(unary.ctor !is null);
		exp = buildClassConstructionWrapper(
			/*#ref*/unary.loc, lp, current, clazz, unary.ctor,
			unary.argumentList);
		return Continue;
	}

	protected Status handleOther(ref ir.Exp exp, ir.Unary unary)
	{
		exp = buildAllocTypePtr(/*#ref*/unary.loc, lp, unary.type);

		return Continue;
	}
}
