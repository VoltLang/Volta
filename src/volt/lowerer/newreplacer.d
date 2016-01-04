// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.newreplacer;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;
import volt.visitor.scopemanager;

import volt.lowerer.array;

import volt.semantic.typer;
import volt.semantic.lookup;
import volt.semantic.mangle;
import volt.semantic.classify;
import volt.semantic.overload;


ir.Function createArrayAllocFunction(Location location, LanguagePass lp, ir.Scope baseScope, ir.ArrayType atype, string name)
{
	auto ftype = new ir.FunctionType();
	ftype.location = location;
	ftype.ret = copyTypeSmart(location, atype);

	/// @todo Change this sucker to buildFunction
	auto fn = new ir.Function();
	fn.location = location;
	fn.type = ftype;
	fn.name = name;
	fn.mangledName = fn.name;
	fn.kind = ir.Function.Kind.Function;
	fn.isWeakLink = true;
	fn.myScope = new ir.Scope(baseScope, fn, fn.name);
	fn._body = new ir.BlockStatement();
	fn._body.myScope = new ir.Scope(fn.myScope, fn._body, null);
	fn._body.location = location;

	auto countVar = addParam(location, fn, buildSizeT(location, lp), "count");

	auto arrayStruct = lp.arrayStruct;
	auto allocDgVar = lp.allocDgVariable;

	auto arrayStructVar = buildVarStatSmart(location, fn._body, fn._body.myScope, arrayStruct, "from");

	auto ptrPfix = new ir.Postfix();
	ptrPfix.location = location;
	ptrPfix.op = ir.Postfix.Op.Identifier;
	ptrPfix.child = buildExpReference(location, arrayStructVar, "from");
	ptrPfix.identifier = new ir.Identifier();
	ptrPfix.identifier.location = location;
	ptrPfix.identifier.value = "ptr";

	auto lengthPfix = new ir.Postfix();
	lengthPfix.location = location;
	lengthPfix.op = ir.Postfix.Op.Identifier;
	lengthPfix.child = buildExpReference(location, arrayStructVar, "from");
	lengthPfix.identifier = new ir.Identifier();
	lengthPfix.identifier.location = location;
	lengthPfix.identifier.value = "length";

	auto ptrAssign = new ir.BinOp();
	ptrAssign.location = location;
	ptrAssign.op = ir.BinOp.Op.Assign;
	ptrAssign.left = ptrPfix;
	ptrAssign.right = createAllocDgCall(
		allocDgVar, lp, location, atype.base,
		buildExpReference(location, countVar, "count"), true);

	auto expStatement = new ir.ExpStatement();
	expStatement.location = location;
	expStatement.exp = ptrAssign;

	fn._body.statements ~= expStatement;

	auto lengthAssign = new ir.BinOp();
	lengthAssign.location = location;
	lengthAssign.op = ir.BinOp.Op.Assign;
	lengthAssign.left = lengthPfix;
	lengthAssign.right = buildExpReference(location, countVar, "count");

	expStatement = new ir.ExpStatement();
	expStatement.location = location;
	expStatement.exp = lengthAssign;

	fn._body.statements ~= expStatement;

	auto addrOf = new ir.Unary();
	addrOf.location = location;
	addrOf.op = ir.Unary.Op.AddrOf;
	addrOf.value = buildExpReference(location, arrayStructVar, "from");

	auto arrayPointer = new ir.PointerType(copyTypeSmart(location, atype));
	arrayPointer.location = location;

	auto _cast = new ir.Unary(arrayPointer, addrOf);
	_cast.location = location;

	auto deref = new ir.Unary();
	deref.location = location;
	deref.op = ir.Unary.Op.Dereference;
	deref.value = _cast;

	auto returnStatement = new ir.ReturnStatement();
	returnStatement.exp = deref;
	returnStatement.location = location;

	fn._body.statements ~= returnStatement;

	return fn;
}

ir.Function getArrayAllocFunction(Location location, LanguagePass lp, ir.Module thisModule, ir.ArrayType atype)
{
	auto arrayMangledName = mangle(atype);
	string name = "__arrayAlloc" ~ arrayMangledName;
	auto allocFn = lookupFunction(lp, thisModule.myScope, location, name);
	if (allocFn is null) {
		allocFn = createArrayAllocFunction(location, lp, thisModule.myScope, atype, name);
		thisModule.children.nodes = allocFn ~ thisModule.children.nodes;
		thisModule.myScope.addFunction(allocFn, allocFn.name);
	}
	return allocFn;
}

ir.StatementExp buildClassConstructionWrapper(Location loc, LanguagePass lp, ir.Scope current, ir.Class _class, ir.Function constructor, ir.Variable allocDgVar, ir.Exp[] exps)
{
	auto sexp = new ir.StatementExp();
	sexp.location = loc;

	// auto thisVar = allocDg(_class, -1);
	auto thisVar = buildVariableSmart(loc, _class, ir.Variable.Storage.Function, "thisVar");
	thisVar.assign = createAllocDgCall(allocDgVar, lp, loc, _class, buildConstantInt(loc, -1));
	thisVar.assign = buildCastSmart(loc, _class, thisVar.assign);
	sexp.statements ~= thisVar;
	sexp.exp = buildExpReference(loc, thisVar, "thisVar");

	// thisVar.this(cast(void*) thisVar)
	auto eref = buildExpReference(loc, constructor, "this");
	auto exp = buildCall(loc, eref, null);
	exp.arguments = buildCast(loc, buildVoidPtr(loc), buildExpReference(loc, thisVar, "thisVar")) ~ exps;
	buildExpStat(loc, sexp, exp);

	return sexp;
}


ir.Exp createAllocDgCall(ir.Variable allocDgVar, LanguagePass lp, Location location, ir.Type type, ir.Exp countArg = null, bool suppressCast = false)
{
	auto adRef = new ir.ExpReference();
	adRef.location = location;
	adRef.idents ~= "allocDg";
	adRef.decl = allocDgVar;

	auto tidExp = new ir.Typeid();
	tidExp.location = location;
	tidExp.type = copyTypeSmart(location, type);

	auto countConst = new ir.Constant();
	countConst.location = location;
	countConst.u._ulong = 0;
	countConst.type = buildSizeT(location, lp);

	auto pfixCall = new ir.Postfix();
	pfixCall.location = location;
	pfixCall.op = ir.Postfix.Op.Call;
	pfixCall.child = adRef;
	pfixCall.arguments ~= tidExp;
	if (countArg is null) {
		pfixCall.arguments ~= countConst;
	} else {
		pfixCall.arguments ~= buildCast(location, buildSizeT(location, lp), countArg);
	}

	if (!suppressCast) {
		auto asTR = cast(ir.TypeReference) type;
		if (asTR !is null) {
			suppressCast = asTR.type.nodeType == ir.NodeType.Class;
		}
	}

	if (!suppressCast) {
		auto result = new ir.PointerType(copyTypeSmart(location, type));
		result.location = location;
		auto resultCast = new ir.Unary(result, pfixCall);
		resultCast.location = location;
		return resultCast;
	} else {
		return pfixCall;
	}
}
	
class NewReplacer : ScopeManager, Pass
{
public:
	ir.Variable allocDgVar;
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
		allocDgVar = lp.allocDgVariable;
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
			if (isIntegral(getExpType(lp, unary.argumentList[0], current))) {
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
			throw panic(unary.location, "multidimensional arrays unsupported at the moment.");
		}

		auto allocFn = getArrayAllocFunction(unary.location, lp, thisModule, array);

		auto _ref = new ir.ExpReference();
		_ref.location = unary.location;
		_ref.idents ~= allocFn.name;
		_ref.decl = allocFn;

		auto call = new ir.Postfix();
		call.location = unary.location;
		call.op = ir.Postfix.Op.Call;
		call.arguments ~= buildCast(unary.location, buildSizeT(unary.location, lp), unary.argumentList[0]);
		call.child = _ref;

		exp = call;

		return Continue;
	}

	protected Status handleArrayCopy(ref ir.Exp exp, ir.Unary unary, ir.ArrayType array)
	{
		auto loc = unary.location;
		auto allocFn = getArrayAllocFunction(loc, lp, thisModule, array);
		auto copyFn = getLlvmMemCopy(loc, lp);

		auto statExp = buildStatementExp(loc);

		auto offset = buildVariable(
			loc, buildSizeT(loc, lp), ir.Variable.Storage.Function,
			"offset", buildConstantSizeT(loc, lp, 0)
		);
		statExp.statements ~= offset;

		ir.Variable[] variables = new ir.Variable[](unary.argumentList.length);
		ir.Exp sizeExp = buildConstantSizeT(loc, lp, 0);
		foreach (i, arg; unary.argumentList) {
			auto var = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp, getExpType(lp, arg, current), arg);
			sizeExp = buildAdd(loc, sizeExp, buildAccess(loc, buildExpReference(loc, var, var.name), "length"));
			variables[i] = var;
		}
		auto newArray = buildVariable(
			loc, copyTypeSmart(loc, array), ir.Variable.Storage.Function,
			"newArray", buildCall(loc, allocFn, [sizeExp], allocFn.name)
		);
		statExp.statements ~= newArray;

		foreach (i, arg; unary.argumentList) {
			auto source = variables[i];

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
					buildAccess(loc, buildExpReference(loc, source, source.name), "length"),
					buildConstantSizeT(loc, lp, size(lp, array.base))
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
							buildAccess(loc, buildExpReference(loc, source, source.name), "length"),
							buildConstantSizeT(loc, lp, size(lp, array.base))
						),
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
		auto ctor = selectFunction(lp, current, clazz.userConstructors, unary.argumentList, unary.location);
		exp = buildClassConstructionWrapper(unary.location, lp, current, clazz, ctor, allocDgVar, unary.argumentList);

		return Continue;
	}

	protected Status handleOther(ref ir.Exp exp, ir.Unary unary)
	{
		exp = createAllocDgCall(allocDgVar, lp, unary.location, unary.type);

		return Continue;
	}
}


