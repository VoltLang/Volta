// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.toplevel;

import lib.llvm.core;

import volt.errors;
import volt.visitor.visitor;
import volt.llvm.di : diVariable;
import volt.llvm.interfaces;


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


	override Status enter(ir.Function fn)
	{
		// Don't export unused functions.
		if (fn._body is null) {
			return ContinueParent;
		}

		Type type;
		auto llvmFunc = state.getFunctionValue(fn, type);
		auto llvmType = type.llvmType;
		auto ft = cast(FunctionType) type;
		assert(ft !is null);

		auto di = diFunction(state, fn, llvmFunc, ft);

		LLVMAddFunctionAttr(llvmFunc, LLVMAttribute.UWTable);

		State.FunctionState old = state.fnState;
		state.fnState = State.FunctionState.init;

		state.fnState.fall = true;
		state.fnState.func = llvmFunc;
		state.fnState.di = di;
		state.fnState.block = LLVMAppendBasicBlock(llvmFunc, "entry");
		LLVMPositionBuilderAtEnd(b, state.block);

		if (fn.kind == ir.Function.Kind.GlobalConstructor) {
			state.globalConstructors ~= llvmFunc;
		} else if (fn.kind == ir.Function.Kind.GlobalDestructor) {
			state.globalDestructors ~= llvmFunc;
		} else if (fn.kind == ir.Function.Kind.LocalConstructor) {
			state.localConstructors ~= llvmFunc;
		} else if (fn.kind == ir.Function.Kind.LocalDestructor) {
			state.localDestructors ~= llvmFunc;
		}

		foreach (uint i, p; fn.params) {
			if (p.name is null)
				continue;

			auto v = LLVMGetParam(llvmFunc, i);

			if (fn.type.isArgRef[i] || fn.type.isArgOut[i]) {
				state.makeByValVariable(p, v);
			} else {
				auto t = state.fromIr(p.type);
				auto a = state.getVariableValue(p, t);
				LLVMBuildStore(state.builder, v, a);
			}
		}

		ir.Variable thisVar = fn.thisHiddenParameter;
		if (thisVar !is null) {
			auto v = LLVMGetParam(llvmFunc, cast(uint)fn.type.params.length);
			state.makeThisVariable(thisVar, v);
		}

		ir.Variable nestVar = fn.nestedHiddenParameter;
		if (nestVar !is null) {
			auto v = LLVMGetParam(llvmFunc, cast(uint)fn.type.params.length);
			state.makeNestVariable(nestVar, v);
		}

		// Go over the function body.
		accept(fn._body, this);

		// Assume language pass knows what it is doing.
		if (state.fall) {
			LLVMBuildCall(state.builder, state.llvmTrap, null);
			LLVMBuildUnreachable(state.builder);
		}

		// Clean up
		state.onFunctionClose();

		state.fnState = old;
		if (fn.isLoweredScopeExit || fn.isLoweredScopeSuccess) {
			state.fnState.path.success ~= llvmFunc;
		}

		// Reset builder for nested functions.
		if (state.block !is null) {
			LLVMPositionBuilderAtEnd(b, state.block);
		}

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
			} else if (var.assign !is null) {
				auto ret = state.getValue(var.assign);
				LLVMBuildStore(state.builder, ret, v);
			} else {
				auto ret = LLVMConstNull(type.llvmType);
				LLVMBuildStore(state.builder, ret, v);
			}
			break;
		case Local:
		case Global:
			if (var.isExtern)
				break;

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

		handleScopeSuccessTo(null);

		Value val;
		if (ret.exp !is null) {
			val = new Value();
			state.getValue(ret.exp, val);

			// Handle void returning functions.
			if (val.type is state.voidType) {
				val = null;
			}
		}

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
		assert(state.fall);

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
		version (D_Version2) state.fnState.swi = State.SwitchState.init;
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
				version (D_Version2) blocks ~= Block(_case, block);
			}
		}
		auto outBlock = LLVMAppendBasicBlockInContext(state.context, state.func, "endSwitch");

		// Generate code for each case.
		auto breakBlock = state.replaceBreakBlock(outBlock);
		foreach (i, block; blocks) {
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
		LLVMBasicBlockRef landingPad, tryDone;

		landingPad = LLVMAppendBasicBlockInContext(
			state.context, state.func, "landingPad");
		tryDone = LLVMAppendBasicBlockInContext(
			state.context, state.func, "tryDone");

		auto iVar = state.ehIndexVar;
		auto eVar = state.ehExceptionVar;

		/*
		 * The try body.
		 */
		assert(state.path.landingBlock is null);
		state.path.landingBlock = landingPad;

		accept(t.tryBlock, this);

		// Reset the landing pad.
		state.path.landingBlock = null;

		if (state.fall) {
			LLVMBuildBr(state.builder, tryDone);
		}

		/*
		 * Landing pad.
		 */
		LLVMMoveBasicBlockAfter(landingPad, state.block);
		state.startBlock(landingPad);
		auto lp = LLVMBuildLandingPad(
			state.builder, state.ehLandingType,
			state.ehPersonalityFunc,
			cast(uint)t.catchVars.length, "");
		auto e = LLVMBuildExtractValue(state.builder, lp, 0, "");
		LLVMBuildStore(state.builder, e, eVar);
		auto i = LLVMBuildExtractValue(state.builder, lp, 1, "");
		LLVMBuildStore(state.builder, i, iVar);

		foreach (size_t index, v; t.catchVars) {
			Type type;
			auto asTR = cast(ir.TypeReference)v.type;
			ir.Class c = cast(ir.Class)asTR.type;
			auto value = state.getVariableValue(c.typeInfo, type);
			value = LLVMBuildBitCast(state.builder, value, state.voidPtrType.llvmType, "");
			LLVMAddClause(lp, value);

			auto fn = state.ehTypeIdFunc;
			auto test = LLVMBuildCall(state.builder, fn, [value]);
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
			LLVMSetCleanup(lp, true);
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
			handleScopeSuccessTo(old);
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

		handleScopeSuccessTo(p);

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

		handleScopeSuccessTo(p);

		LLVMBuildBr(state.builder, p.breakBlock);
		state.fnState.fall = false;

		return Continue;
	}

	override Status leave(ir.GotoStatement gs)
	{
		// Goto will exit the scope just as if it was a break.
		auto p = state.findBreak();
		handleScopeSuccessTo(p);

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

	override Status leave(ir.Module m)
	{
		void globalAppendArray(LLVMValueRef[] arr, const(char)* name)
		{
			if (arr.length == 0) {
				return;
			}
			auto fnty = LLVMTypeOf(arr[0]);
			auto stypes = [LLVMInt32TypeInContext(state.context), fnty];
			auto _struct = LLVMStructTypeInContext(state.context, stypes.ptr, 2, false);
			auto array = LLVMArrayType(_struct, cast(uint) arr.length);
			auto gval = LLVMAddGlobal(state.mod, array, name);
			LLVMSetLinkage(gval, LLVMLinkage.Appending);

			LLVMValueRef[] structs;
			foreach (fn; arr) {
				// These version blocks brought to you by LLVM being terrible.
				uint priority = 2;
				version (Windows) priority = 1;
				if (m.name.strings == ["vrt", "vmain"]) {
					priority = 1;
					version (Windows) priority = 2;
				}
				auto vals = [LLVMConstInt(LLVMInt32TypeInContext(state.context), priority, false), fn];
				structs ~= LLVMConstStructInContext(state.context, vals.ptr, 2, false);
			}
			auto lit = LLVMConstArray(_struct, structs.ptr, cast(uint) arr.length);
			LLVMSetInitializer(gval, lit);
		}

		globalAppendArray(state.globalConstructors, "llvm.global_ctors");
		globalAppendArray(state.globalDestructors, "llvm.global_dtors");

		if (state.localConstructors.length > 0 || state.localDestructors.length > 0) {
			throw panic(m.location, "local constructor or destructor made it into llvm backend.");
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

	void handleScopeSuccessTo(State.PathState to)
	{
		LLVMValueRef[] funcs;
		auto p = state.path;
		while (p !is to) {
			if (p.success.length > 0) {
				funcs = p.success ~ funcs;
			}
			p = p.prev;
		}

		if (funcs.length == 0) {
			return;
		}

		auto value = LLVMBuildBitCast(
			state.builder, state.fnState.nested,
			state.voidPtrType.llvmType, "");
		auto arg = [value];
		foreach_reverse (fn; funcs) {
			state.buildCallOrInvoke(fn, arg);
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
	override Status leave(ir.Function fn) { assert(false); }
	override Status leave(ir.IfStatement i) { assert(false); }
	override Status leave(ir.ExpStatement e) { assert(false); }
	override Status leave(ir.BlockStatement b) { assert(false); }
	override Status leave(ir.ReturnStatement r) { assert(false); }
}
