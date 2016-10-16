// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.toplevel;

import watt.text.format : format;

import lib.llvm.core;

import volt.errors;
import volt.visitor.visitor;
import volt.semantic.classify;
import volt.llvm.di : diVariable;
import volt.llvm.interfaces;
import ir = volt.ir.ir;


class LlvmVisitor : NullVisitor
{
public:
	State state;
	LLVMModuleRef mod;
	LLVMBuilderRef b;


public:
	this(State lv)
	{
		this.state = lv;
		this.mod = lv.mod;
		this.b = lv.builder;
	}

	void compile(ir.Module m)
	{
		accept(m, this);
	}


	/*
	 *
	 * TopLevel
	 *
	 */


	override Status enter(ir.Function func)
	{
		Type type;
		auto llvmFunc = state.getFunctionValue(func, type);
		auto llvmType = type.llvmType;

		if (func.loadDynamic) {
			auto init = LLVMConstNull(llvmType);
			LLVMSetInitializer(llvmFunc, init);
			return ContinueParent;
		}

		// Don't export unused functions.
		if (func._body is null) {
			return ContinueParent;
		}

		auto ft = cast(FunctionType) type;
		assert(ft !is null);

		auto di = diFunction(state, func, llvmFunc, ft);

		State.FunctionState old = state.fnState;
		state.fnState = State.FunctionState.init;

		state.fnState.fall = true;
		state.fnState.func = llvmFunc;
		state.fnState.di = di;
		state.fnState.block = LLVMAppendBasicBlock(llvmFunc, "entry");
		LLVMPositionBuilderAtEnd(b, state.block);

		// Set position for various setup instructions.
		diSetPosition(state, func.location);

		if (func.kind == ir.Function.Kind.GlobalConstructor) {
			state.globalConstructors ~= llvmFunc;
		} else if (func.kind == ir.Function.Kind.GlobalDestructor) {
			state.globalDestructors ~= llvmFunc;
		} else if (func.kind == ir.Function.Kind.LocalConstructor) {
			state.localConstructors ~= llvmFunc;
		} else if (func.kind == ir.Function.Kind.LocalDestructor) {
			state.localDestructors ~= llvmFunc;
		}

		size_t offset = func.type.hiddenParameter;
		foreach (irIndex, p; func.params) {
			auto v = LLVMGetParam(llvmFunc, cast(uint)(irIndex + offset));
			auto t = state.fromIr(p.type);

			bool isRef = func.type.isArgRef[irIndex];
			bool isOut = func.type.isArgOut[irIndex];
			bool isStruct = t.passByVal;

			// These two condition has to happen
			// even if the parameter isn't nameed.
			if (isOut) {
				auto initC = LLVMConstNull(t.llvmType);
				LLVMBuildStore(state.builder, initC, v);
			} else if (isStruct && !isRef) {
				LLVMAddAttribute(v, LLVMAttribute.ByVal);
			}

			// Early out on unmaned parameters.
			if (p.name is null) {
				continue;
			} else if (isRef || isOut || isStruct) {
				state.makeByValVariable(p, v);
			} else {
				auto a = state.getVariableValue(p, t);
				LLVMBuildStore(state.builder, v, a);
			}
		}

		ir.Variable thisVar = func.thisHiddenParameter;
		if (thisVar !is null) {
			auto v = LLVMGetParam(llvmFunc, 0);
			state.makeThisVariable(thisVar, v);
		}

		ir.Variable nestVar = func.nestedHiddenParameter;
		if (nestVar !is null) {
			auto v = LLVMGetParam(llvmFunc, 0);
			state.makeNestVariable(nestVar, v);
		}

		// Reset position.
		diUnsetPosition(state);

		// Go over the function body.
		accept(func._body, this);

		// Assume language pass knows what it is doing.
		if (state.fall) {
			LLVMBuildCall(state.builder, state.llvmTrap, null);
			LLVMBuildUnreachable(state.builder);
		}

		// Clean up
		state.onFunctionClose();
		state.fnState = old;

		// Reset builder for nested functions.
		if (state.block !is null) {
			LLVMPositionBuilderAtEnd(b, state.block);
		}
		auto oldBlock = state.block;
		state.startBlock(oldBlock);

		handleScopedFunction(func, llvmFunc);

		return ContinueParent;
	}

	override Status enter(ir.Variable var)
	{
		Type type;

		final switch(var.storage) with (ir.Variable.Storage) {
		case Invalid:
			assert(false, "invalid variable");
		case Field:
			break;
		case Function, Nested:
			assert(state.func !is null);

			auto v = state.getVariableValue(var, type);

			if (var.specialInitValue) {
				assert(var.assign is null);
				break;
			} else if (var.assign !is null) {
				auto ret = state.getValue(var.assign);
				LLVMBuildStore(state.builder, ret, v);
				break;
			}

			auto s = size(state.lp, type.irType);
			if (s < 64) {
				auto ret = LLVMConstNull(type.llvmType);
				LLVMBuildStore(state.builder, ret, v);
				break;
			}

			v = LLVMBuildBitCast(state.builder, v, state.voidPtrType.llvmType, "");
			auto memset = state.lp.target.isP64 ?
				state.lp.llvmMemset64 :
				state.lp.llvmMemset32;
			auto func = state.getFunctionValue(memset, type);
			LLVMBuildCall(state.builder, func, [v,
					LLVMConstInt(state.ubyteType.llvmType, 0, false),
					LLVMConstInt(state.sizeType.llvmType, s, false),
					LLVMConstInt(state.intType.llvmType, 0, true),
					LLVMConstInt(state.boolType.llvmType, 0, false)]);

			break;
		case Local:
		case Global:
			if (var.isExtern) {
				break;
			}

			LLVMValueRef init;
			auto v = state.getVariableValue(var, type);

			if (var.assign !is null) {
				init = state.getConstant(var.assign);
			} else {
				init = LLVMConstNull(type.llvmType);
			}
			LLVMSetInitializer(v, init);
			state.diVariable(v, var, type);
			break;
		}

		return ContinueParent;
	}


	/*
	 *
	 * Statements
	 *
	 */


	override Status enter(ir.ReturnStatement ret)
	{
		assert(state.fall);

		Value val;
		if (ret.exp !is null) {
			val = new Value();
			state.getValue(ret.exp, val);

			// Handle void returning functions.
			if (val.type is state.voidType) {
				val = null;
			}
		}

		handleScopeSuccessTo(ret.location, null);

		diSetPosition(state, ret.location);

		if (val is null) {
			LLVMBuildRet(b, null);
		} else {
			LLVMBuildRet(b, val.value);
		}

		diUnsetPosition(state);

		state.fnState.fall = false;

		return ContinueParent;
	}

	override Status enter(ir.ExpStatement exps)
	{
		panicAssert(exps, state.fall);

		// XXX: Should we do something here?
		auto ret = state.getValue(exps.exp);

		return ContinueParent;
	}

	// Have to move this here for now.
	struct Block
	{
		ir.SwitchCase _case;
		LLVMBasicBlockRef block;
	}

	override Status enter(ir.SwitchStatement ss)
	{
		assert(state.fall);

		auto cond = state.getValue(ss.condition);

		Block[] blocks;

		auto old = state.fnState.swi;
		state.fnState.swi = State.SwitchState.init;
		// Even final switches have an (invalid) default case.
		state.fnState.swi.def = LLVMAppendBasicBlockInContext(state.context, state.func, "defaultCase");
		ir.BlockStatement defaultStatements;
		auto _switch = LLVMBuildSwitch(state.builder, cond, state.switchDefault, cast(uint)(ss.cases.length));

		foreach (_case; ss.cases) {
			if (_case.firstExp !is null) acceptExp(_case.firstExp, this);
			void addVal(LLVMValueRef val, LLVMBasicBlockRef block)
			{
				LLVMBasicBlockRef tmp;
				auto i = LLVMConstIntGetSExtValue(val);
				if (state.switchGetCase(i, tmp)) {
					throw makeSwitchDuplicateCase(_case);
				} else {
					state.switchSetCase(i, block);
				}
				LLVMAddCase(_switch, val, block);
				version (Volt) return; // If, throw?
			}

			void addExp(ir.Exp exp, LLVMBasicBlockRef block)
			{
				if (exp is null) {
					return;
				}
				auto val = state.getValue(exp);
				addVal(val, block);
			}

			if (_case.isDefault) {
				defaultStatements = _case.statements;
				Block add = { _case, state.fnState.swi.def };
				blocks ~= add;
			} else {
				auto block = LLVMAppendBasicBlockInContext(state.context, state.func, "switchCase");
				if (_case.firstExp !is null && _case.secondExp !is null) {
					// case A: .. case B:
					auto aval = state.getValue(_case.firstExp);
					auto bval = state.getValue(_case.secondExp);
					auto typ = LLVMTypeOf(aval);
					auto ai = LLVMConstIntGetSExtValue(aval);
					auto bi = LLVMConstIntGetSExtValue(bval);
					if (ai >= bi) {
						throw panic(ss.location, "invalid case range");
					}
					while (ai <= bi) {
						auto val = LLVMConstInt(typ, cast(ulong)ai++, false);
						addVal(val, block);
					}
				} else {
					addExp(_case.firstExp, block);
					foreach (exp; _case.exps) addExp(exp, block);
				}
				Block add = { _case, block };
				blocks ~= add;
			}
		}
		auto outBlock = LLVMAppendBasicBlockInContext(state.context, state.func, "endSwitch");

		// Generate code for each case.
		auto breakBlock = state.replaceBreakBlock(outBlock);
		foreach (i, block; blocks) {
			if (block._case.isDefault) {
				continue;
			}
			state.startBlock(block.block);
			doNewBlock(block.block, block._case.statements, i == blocks.length - 1 ? outBlock : blocks[i+1].block);
		}
		state.startBlock(state.switchDefault);
		if (defaultStatements !is null) {
			doNewBlock(state.switchDefault, defaultStatements, outBlock);
		} else {
			// No default block (e.g. final switches)
			LLVMBuildCall(state.builder, state.llvmTrap, null);
			LLVMBuildUnreachable(state.builder);
		}
		state.replaceBreakBlock(breakBlock);

		// Continue generating code after the switch.
		LLVMMoveBasicBlockAfter(outBlock, state.block);
		state.startBlock(outBlock);

		state.fnState.swi = old;

		return ContinueParent;
	}

	override Status enter(ir.TryStatement t)
	{
		LLVMBasicBlockRef landingPad, catchBlock, tryDone;

		landingPad = LLVMAppendBasicBlockInContext(
			state.context, state.func, "landingPad");
		tryDone = LLVMAppendBasicBlockInContext(
			state.context, state.func, "tryDone");
		catchBlock = LLVMAppendBasicBlockInContext(
			state.context, state.func, "catchBlock");


		/*
		 * Setup catch block, catch types and landingpad state.
		 */
		state.pushPath();
		auto p = state.path;

		p.catchBlock = catchBlock;
		p.landingBlock = landingPad;
		p.catchTypeInfos = new LLVMValueRef[](t.catchVars.length);
		foreach (index, v; t.catchVars) {
			Type type;
			auto asTR = cast(ir.TypeReference) v.type;
			ir.Class c = cast(ir.Class) asTR.type;
			p.catchTypeInfos[index] = state.getVariableValue(c.typeInfo, type);
		}


		/*
		 * The try body.
		 */
		accept(t.tryBlock, this);

		if (state.fall) {
			LLVMBuildBr(state.builder, tryDone);
		}


		/*
		 * Landing pad.
		 */
		State.PathState dummy;
		LLVMMoveBasicBlockAfter(landingPad, state.block);
		fillInLandingPad(landingPad, t.finallyBlock !is null, dummy);
		assert(dummy is p);

		// Reset the path.
		state.popPath();


		/*
		 * Catch code.
		 */
		LLVMBuildBr(state.builder, catchBlock);
		LLVMMoveBasicBlockAfter(catchBlock, state.block);
		state.startBlock(catchBlock);

		auto e = LLVMBuildLoad(state.builder, state.ehExceptionVar, "");
		auto i = LLVMBuildLoad(state.builder, state.ehIndexVar, "");
		foreach (index, v; t.catchVars) {
			Type type;
			auto asTR = cast(ir.TypeReference)v.type;
			ir.Class c = cast(ir.Class)asTR.type;
			auto value = state.getVariableValue(c.typeInfo, type);
			value = LLVMBuildBitCast(state.builder, value, state.voidPtrType.llvmType, "");

			auto func = state.ehTypeIdFunc;
			auto test = LLVMBuildCall(state.builder, func, [value]);
			test = LLVMBuildICmp(state.builder, LLVMIntPredicate.EQ, test, i, "");


			LLVMBasicBlockRef thenBlock, elseBlock;
			thenBlock = LLVMAppendBasicBlockInContext(
					state.context, state.func, "ifTrue");

			elseBlock = LLVMAppendBasicBlockInContext(
					state.context, state.func, "ifFalse");


			LLVMBuildCondBr(state.builder, test, thenBlock, elseBlock);
			LLVMMoveBasicBlockAfter(thenBlock, state.block);
			state.startBlock(thenBlock);

			auto ptr = state.getVariableValue(v, type);
			value = LLVMBuildBitCast(state.builder, e, type.llvmType, "");
			LLVMBuildStore(state.builder, value, ptr);

			accept(t.catchBlocks[index], this);

			if (state.fall) {
				LLVMBuildBr(state.builder, tryDone);
			}

			LLVMMoveBasicBlockAfter(elseBlock, state.block);
			state.startBlock(elseBlock);
		}

		/*
		 * Finally block.
		 */
		if (t.finallyBlock !is null) {
			accept(t.finallyBlock, this);
			LLVMBuildBr(state.builder, state.ehResumeBlock);
			throw panic(t.finallyBlock, "does not support finally statements");
		} else {
			LLVMBuildBr(state.builder, state.ehResumeBlock);
		}

		/*
		 * Everything after the try statement.
		 */
		LLVMMoveBasicBlockAfter(tryDone, state.block);
		state.startBlock(tryDone);

		return ContinueParent;
	}

	override Status enter(ir.IfStatement ifs)
	{
		assert(state.fall);

		auto cond = state.getValue(ifs.exp);

		bool hasElse = ifs.elseState !is null;
		LLVMBasicBlockRef thenBlock, elseBlock, endBlock;

		thenBlock = LLVMAppendBasicBlockInContext(
			state.context, state.func, "ifTrue");
		if (hasElse)
			elseBlock = LLVMAppendBasicBlockInContext(
				state.context, state.func, "ifFalse");
		endBlock = LLVMAppendBasicBlockInContext(
			state.context, state.func, "endIf");

		// Condition placed in the current block.
		LLVMBuildCondBr(state.builder, cond, thenBlock,
			hasElse ? elseBlock : endBlock);

		// Do new then block after the current block.
		doNewBlock(thenBlock, ifs.thenState, endBlock);

		// Any else block, after any block that might have be added.
		if (hasElse) {
			doNewBlock(elseBlock, ifs.elseState, endBlock);
		}

		// And the out block.
		LLVMMoveBasicBlockAfter(endBlock, state.block);
		state.startBlock(endBlock);

		return ContinueParent;
	}

	override Status enter(ir.WhileStatement w)
	{
		assert(state.fall);

		LLVMBasicBlockRef whileCond, whileBody, whileOut;

		whileCond = LLVMAppendBasicBlockInContext(
			state.context, state.func, "whileCond");
		whileBody = LLVMAppendBasicBlockInContext(
			state.context, state.func, "whileBody");
		whileOut = LLVMAppendBasicBlockInContext(
			state.context, state.func, "whileOut");

		// Make continue jump to the cond block, and break to out.
		auto saveBre = state.replaceBreakBlock(whileOut);
		auto saveCon = state.replaceContinueBlock(whileCond);

		// Jump to the cond block.
		LLVMBuildBr(state.builder, whileCond);

		// Do while cond.
		state.startBlock(whileCond);
		auto cond = state.getValue(w.condition);
		LLVMBuildCondBr(state.builder, cond, whileBody, whileOut);

		// Do whileBody
		doNewBlock(whileBody, w.block, whileCond);

		// Switch out block
		LLVMMoveBasicBlockAfter(whileOut, state.block);
		state.startBlock(whileOut);
		state.replaceBreakBlock(saveBre);
		state.replaceContinueBlock(saveCon);

		return ContinueParent;
	}

	override Status enter(ir.DoStatement d)
	{
		assert(state.fall);

		LLVMBasicBlockRef doCond, doBody, doOut;

		doBody = LLVMAppendBasicBlockInContext(
			state.context, state.func, "doBody");
		doCond = LLVMAppendBasicBlockInContext(
			state.context, state.func, "doCond");
		doOut = LLVMAppendBasicBlockInContext(
			state.context, state.func, "doOut");

		// Make continue jump to the cond block, and break to out.
		auto saveBre = state.replaceBreakBlock(doOut);
		auto saveCon = state.replaceContinueBlock(doCond);

		// Jump to the body block
		LLVMBuildBr(state.builder, doBody);

		// Do followed by the body
		doNewBlock(doBody, d.block, doCond);

		// Do the while statement part
		LLVMMoveBasicBlockAfter(doCond, state.block);
		state.startBlock(doCond);
		auto cond = state.getValue(d.condition);
		LLVMBuildCondBr(state.builder, cond, doBody, doOut);

		// Switch out block
		LLVMMoveBasicBlockAfter(doOut, state.block);
		state.startBlock(doOut);
		state.replaceBreakBlock(saveBre);
		state.replaceContinueBlock(saveCon);

		return ContinueParent;
	}

	override Status enter(ir.ForStatement f)
	{
		LLVMBasicBlockRef forCond, forBody, forPost, forOut;

		forCond = LLVMAppendBasicBlockInContext(
			state.context, state.func, "forCond");
		forBody = LLVMAppendBasicBlockInContext(
			state.context, state.func, "forBody");
		forPost = LLVMAppendBasicBlockInContext(
			state.context, state.func, "forPost");
		forOut = LLVMAppendBasicBlockInContext(
			state.context, state.func, "forOut");

		// Init stuff go into the fnState.block
		foreach (var; f.initVars)
			enter(var);
		foreach (exp; f.initExps)
			state.getValue(exp);

		// Make continue jump to the post block, and break to out.
		auto saveBre = state.replaceBreakBlock(forOut);
		auto saveCon = state.replaceContinueBlock(forPost);

		// Jump to the cond block
		LLVMBuildBr(state.builder, forCond);

		// Do while cond.
		state.startBlock(forCond);
		LLVMValueRef cond;
		if (f.test is null) {
			cond = LLVMConstInt(LLVMInt1Type(), 1, false);
		} else {
			cond = state.getValue(f.test);
		}
		LLVMBuildCondBr(state.builder, cond, forBody, forOut);

		// Main body
		doNewBlock(forBody, f.block, forPost);

		// For post block
		LLVMMoveBasicBlockAfter(forPost, state.block);
		state.startBlock(forPost);

		foreach (exp; f.increments) {
			state.getValue(exp);
		}

		// End the increment block with jump back to cond
		LLVMBuildBr(state.builder, forCond);

		// For out block
		LLVMMoveBasicBlockAfter(forOut, state.block);
		state.startBlock(forOut);
		state.replaceBreakBlock(saveBre);
		state.replaceContinueBlock(saveCon);

		return ContinueParent;
	}

	override Status enter(ir.BlockStatement bs)
	{
		auto old = state.path;
		state.pushPath();

		foreach (s; bs.statements) {
			accept(s, this);
		}

		if (state.fall) {
			// TODO Add a endBraceLocation field to BlockStatement.
			handleScopeSuccessTo(bs.location, old);
		}

		state.popPath();
		return ContinueParent;
	}

	override Status visit(ir.ContinueStatement cs)
	{
		auto p = state.findContinue();

		if (cs.label !is null) {
			throw panic(cs.location, "labled continue statements not supported");
		}

		handleScopeSuccessTo(cs.location, p);

		LLVMBuildBr(state.builder, p.continueBlock);
		state.fnState.fall = false;

		return Continue;
	}

	override Status visit(ir.BreakStatement bs)
	{
		auto p = state.findBreak();

		if (bs.label !is null) {
			throw panic(bs.location, "labled break statements not supported");
		}

		handleScopeSuccessTo(bs.location, p);

		LLVMBuildBr(state.builder, p.breakBlock);
		state.fnState.fall = false;

		return Continue;
	}

	override Status leave(ir.GotoStatement gs)
	{
		// Goto will exit the scope just as if it was a break.
		auto p = state.findBreak();
		handleScopeSuccessTo(gs.location, p);

		if (gs.isDefault) {
			LLVMBuildBr(state.builder, state.switchDefault);
			state.fnState.fall = false;
		} else if (gs.isCase) {
			if (gs.exp is null) {
				// TODO XXX this is a bug.
				state.fnState.fall = true;
			} else {
				auto v = state.getValue(gs.exp);
				auto i = LLVMConstIntGetSExtValue(v);
				LLVMBasicBlockRef b;

				if (!state.switchGetCase(i, b)) {
					throw makeExpected(gs.location, "valid case");
				}
				LLVMBuildBr(state.builder, b);
				state.fnState.fall = false;
			}
		} else {
			throw panic(gs.location, "non switch goto");
		}
		return Continue;
	}

	override Status leave(ir.ThrowStatement t)
	{
		// Should not call success here.

		if (t.exp is null) {
			throw panic(t.location, "empty throw statement");
		}
	
		state.getValue(t.exp);
		LLVMBuildUnreachable(state.builder);
		state.fnState.fall = false;

		return Continue;
	}

	void globalStructorArray(ir.Module m, LLVMValueRef[] arr, string name)
	{
		if (arr.length == 0) {
			return;
		}
		auto fnty = LLVMTypeOf(arr[0]);
		auto stypes = [LLVMInt32TypeInContext(state.context), fnty];
		auto _struct = LLVMStructTypeInContext(state.context, stypes, false);

		auto structs = new LLVMValueRef[](arr.length);
		foreach (i, func; arr) {
			uint priority = 65535;
			auto vals = [LLVMConstInt(LLVMInt32TypeInContext(state.context), priority, false), func];
			structs[i] = LLVMConstStructInContext(state.context, vals.ptr, 2, false);
		}
		auto array = LLVMArrayType(_struct, cast(uint) arr.length);
		auto gval = LLVMAddGlobal(state.mod, array, name);
		auto lit = LLVMConstArray(_struct, structs);
		LLVMSetInitializer(gval, lit);
		LLVMSetLinkage(gval, LLVMLinkage.Appending);
	}

	LLVMValueRef globalModuleInfo(ir.Module m)
	{
		string name = "_V__ModuleInfo_";
		foreach (i; m.name.identifiers) {
			name = format("%s%s%s", name, i.value.length, i.value);
		}

		auto t = cast(StructType)state.fromIr(state.lp.moduleInfo);
		assert(t !is null);
		auto at = cast(ArrayType)t.types[1];
		assert(at !is null);

		LLVMValueRef[3] vals;
		vals[0] = LLVMConstNull(t.types[0].llvmType);
		vals[1] = at.from(state, state.globalConstructors);
		vals[2] = at.from(state, state.globalDestructors);
		auto lit = LLVMConstNamedStruct(t.llvmType, vals);

		auto gval = LLVMAddGlobal(state.mod, t.llvmType, name);
		LLVMSetInitializer(gval, lit);
		return gval;
	}

	void makeModuleInfoFunction(ir.Module m)
	{
		Type t;

		// Emit and get the ModuleInfo for this module.
		auto gval = globalModuleInfo(m);

		// Create 'real' ctor to add the module info to rootModuleInfo.
		auto func = LLVMAddFunction(state.mod, "__global_ctor",
			state.voidFunctionType.llvmCallType);
		LLVMSetLinkage(func, LLVMLinkage.Internal);

		auto b = LLVMAppendBasicBlock(func, "entry");
		LLVMPositionBuilderAtEnd(state.builder, b);

		auto root = state.getVariableValue(state.lp.moduleInfoRoot, t);
		auto first = LLVMBuildStructGEP(state.builder, gval, 0, "");
		auto old = LLVMBuildLoad(state.builder, root, "");
		LLVMBuildStore(state.builder, old, first);
		LLVMBuildStore(state.builder, gval, root);
		LLVMBuildRet(state.builder, null);

		globalStructorArray(m, [func], "llvm.global_ctors");
	}

	override Status leave(ir.Module m)
	{
		if (state.localConstructors.length > 0 || state.localDestructors.length > 0) {
			throw panic(m.location, "local constructor or destructor made it into llvm backend.");
		}

		if (state.globalConstructors.length > 0 ||
		    state.globalDestructors.length > 0 ||
		    state.localConstructors.length > 0 ||
		    state.localDestructors.length > 0) {
			makeModuleInfoFunction(m);
		}
		return Continue;
	}

	void doNewBlock(LLVMBasicBlockRef b, ir.BlockStatement bs,
	                LLVMBasicBlockRef fall)
	{
		LLVMMoveBasicBlockAfter(b, state.block);
		state.startBlock(b);
		accept(bs, this);
		if (state.fall)
			LLVMBuildBr(state.builder, fall);
	}

	void handleScopeSuccessTo(ref Location loc, State.PathState to)
	{
		LLVMValueRef[] arg;
		void buildArgIfNeeded() {
			if (arg.length) {
				return;
			}
			auto value = LLVMBuildBitCast(
				state.builder, state.fnState.nested,
				state.voidPtrType.llvmType, "");
			arg = [value];
		}


		auto p = state.path;
		while (p !is to) {
			foreach_reverse (index, func; p.scopeSuccess) {
				if (func is null) {
					continue;
				}

				buildArgIfNeeded();
				auto pad = p.scopeLanding[index];
				state.buildCallOrInvoke(loc, func, arg, pad);
			}
			p = p.prev;
		}
	}

	void handleScopedFunction(ir.Function func, LLVMValueRef llvmFunc)
	{
		auto success = func.isLoweredScopeExit | func.isLoweredScopeSuccess;
		auto failure = func.isLoweredScopeExit | func.isLoweredScopeFailure;

		// Nothing needs to be done
		if (!success && !failure) {
			return;
		}

		auto landingPath = state.findLanding();
		state.path.scopeSuccess ~= success ? llvmFunc : null;
		state.path.scopeFailure ~= failure ? llvmFunc : null;
		state.path.scopeLanding ~= landingPath !is null ?
			landingPath.landingBlock : null;

		// Don't need to generate a landingPad
		if (!failure) {
			return;
		}

		auto oldBlock = state.block;
		auto landingPad = LLVMAppendBasicBlockInContext(
			state.context, state.func, "landingPad");

		State.PathState catchPath;
		fillInLandingPad(landingPad, true, catchPath);

		auto value = LLVMBuildBitCast(
			state.builder, state.fnState.nested,
			state.voidPtrType.llvmType, "");
		auto arg = [value];

		auto p = state.path;
		while (p !is null) {
			foreach_reverse (loopFunc; p.scopeFailure) {
				if (loopFunc is null) {
					continue;
				}
				LLVMBuildCall(state.builder, loopFunc, arg);
			}

			if (p is catchPath) {
				break;
			}
			p = p.prev;
		}

		state.path.landingBlock = landingPad;
		if (catchPath is null) {
			LLVMBuildBr(state.builder, state.ehResumeBlock);
		} else {
			LLVMBuildBr(state.builder, catchPath.catchBlock);
		}

		state.startBlock(oldBlock);
	}

	/*
	 * Fills in the given landing pad.
	 *
	 * Side-effects:
	 *   Will set the landingPad as the current working block.
	 */
	void fillInLandingPad(LLVMBasicBlockRef landingPad, bool setCleanup,
	                      out State.PathState catchPath)
	{
		catchPath = state.findCatch();
		auto catches = catchPath !is null ? catchPath.catchTypeInfos : null;

		state.startBlock(landingPad);
		auto lp = LLVMBuildLandingPad(
			state.builder, state.ehLandingType,
			state.ehPersonalityFunc,
			cast(uint)catches.length, "");
		auto e = LLVMBuildExtractValue(state.builder, lp, 0, "");
		LLVMBuildStore(state.builder, e, state.ehExceptionVar);
		auto i = LLVMBuildExtractValue(state.builder, lp, 1, "");
		LLVMBuildStore(state.builder, i, state.ehIndexVar);

		LLVMSetCleanup(lp, setCleanup);
		foreach (ti; catches) {
			LLVMAddClause(lp, ti);
		}
	}

	/*
	 * Ignore but pass.
	 */
	override Status enter(ir.Module m) { return Continue; }

	/*
	 * Should not enter.
	 */
	override Status leave(ir.Variable v) { assert(false); }
	override Status leave(ir.Function f) { assert(false); }
	override Status leave(ir.IfStatement i) { assert(false); }
	override Status leave(ir.ExpStatement e) { assert(false); }
	override Status leave(ir.BlockStatement b) { assert(false); }
	override Status leave(ir.ReturnStatement r) { assert(false); }
}
