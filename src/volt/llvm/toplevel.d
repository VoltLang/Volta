// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.toplevel;

import lib.llvm.core;

import volt.exceptions;
import volt.visitor.visitor;
import volt.llvm.type;
import volt.llvm.state;
import volt.llvm.constant;
import volt.llvm.expression;


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
		Type type;
		auto llvmFunc = state.getFunctionValue(fn, type);
		if (fn.type.linkage == ir.Linkage.Windows) {
			LLVMSetFunctionCallConv(llvmFunc, LLVMCallConv.X86Stdcall);
		}
		auto llvmType = type.llvmType;
		auto ct = cast(CallableType)type;
		assert(ct !is null);

		if (fn._body !is null) {
			state.currentFall = true;
			state.currentFunc = llvmFunc;
			state.currentBlock = LLVMAppendBasicBlock(llvmFunc, "entry");
			LLVMPositionBuilderAtEnd(b, state.currentBlock);

			foreach(uint i, p; fn.type.params) {
				if (p.name is null)
					continue;

				auto t = state.fromIr(fn.type.params[i].type);
				auto v = LLVMGetParam(llvmFunc, i);
				auto a = state.getVariableValue(p, t);
				LLVMBuildStore(state.builder, v, a);
			}

			ir.Variable thisVar = fn.thisHiddenParameter;
			if (thisVar !is null) {
				auto v = LLVMGetParam(llvmFunc, cast(uint)fn.type.params.length);
				state.makeThisVariable(thisVar, v);
			}

			foreach(n; fn._body.statements)
				accept(n, this);

			// Assume language pass knows what it is doing.
			if (state.currentFall) {
				LLVMBuildCall(state.builder, state.llvmTrap, null);
				LLVMBuildUnreachable(state.builder);
			}

			state.currentFall = false;
			state.currentFunc = null;
			state.currentBlock = null;
		}

		return ContinueParent;
	}

	override Status enter(ir.Variable var)
	{
		Type type;

		final switch(var.storage) with (ir.Variable.Storage) {
		case None:
			// Variables declared in structs.
			/// @todo mark members with a special storage type.
			if (state.currentFunc is null)
				break;

			auto v = state.getVariableValue(var, type);

			if (var.assign !is null) {
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
				init = state.getConstantValue(var.assign);
			} else {
				init = LLVMConstNull(type.llvmType);
			}
			LLVMSetInitializer(v, init);
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
		assert(state.currentFall);

		if (ret.exp is null) {
			LLVMBuildRet(b, null);
		} else {
			LLVMBuildRet(b, state.getValue(ret.exp));
		}

		state.currentFall = false;

		return ContinueParent;
	}

	override Status enter(ir.ExpStatement exps)
	{
		assert(state.currentFall);

		// XXX: Should we do something here?
		auto ret = state.getValue(exps.exp);

		return ContinueParent;
	}

	override Status enter(ir.IfStatement ifs)
	{
		assert(state.currentFall);

		auto cond = state.getValue(ifs.exp);

		bool hasElse = ifs.elseState !is null;
		LLVMBasicBlockRef thenBlock, elseBlock, endBlock;

		thenBlock = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "ifTrue");
		if (hasElse)
			elseBlock = LLVMAppendBasicBlockInContext(
				state.context, state.currentFunc, "ifFalse");
		endBlock = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "endIf");

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
		LLVMMoveBasicBlockAfter(endBlock, state.currentBlock);
		state.startBlock(endBlock);

		return ContinueParent;
	}

	override Status enter(ir.WhileStatement w)
	{
		assert(state.currentFall);

		LLVMBasicBlockRef whileCond, whileBody, whileOut;

		whileCond = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "whileCond");
		whileBody = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "whileBody");
		whileOut = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "whileOut");

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
		LLVMMoveBasicBlockAfter(whileOut, state.currentBlock);
		state.startBlock(whileOut);
		state.replaceBreakBlock(saveBre);
		state.replaceContinueBlock(saveCon);

		return ContinueParent;
	}

	override Status enter(ir.DoStatement d)
	{
		assert(state.currentFall);

		LLVMBasicBlockRef doCond, doBody, doOut;

		doBody = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "doBody");
		doCond = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "doCond");
		doOut = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "doOut");

		// Make continue jump to the cond block, and break to out.
		auto saveBre = state.replaceBreakBlock(doOut);
		auto saveCon = state.replaceContinueBlock(doCond);

		// Jump to the body block
		LLVMBuildBr(state.builder, doBody);

		// Do followed by the body
		doNewBlock(doBody, d.block, doCond);

		// Do the while statement part
		LLVMMoveBasicBlockAfter(doCond, state.currentBlock);
		state.startBlock(doCond);
		auto cond = state.getValue(d.condition);
		LLVMBuildCondBr(state.builder, cond, doBody, doOut);

		// Switch out block
		LLVMMoveBasicBlockAfter(doOut, state.currentBlock);
		state.startBlock(doOut);
		state.replaceBreakBlock(saveBre);
		state.replaceContinueBlock(saveCon);

		return ContinueParent;
	}

	override Status enter(ir.ForStatement f)
	{
		LLVMBasicBlockRef forCond, forBody, forPost, forOut;

		forCond = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "forCond");
		forBody = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "forBody");
		forPost = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "forPost");
		forOut = LLVMAppendBasicBlockInContext(
			state.context, state.currentFunc, "forOut");

		// Init stuff go into the currentBlock
		foreach(var; f.initVars)
			enter(var);
		foreach(exp; f.initExps)
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
		LLVMMoveBasicBlockAfter(forPost, state.currentBlock);
		state.startBlock(forPost);

		foreach(exp; f.increments) {
			state.getValue(exp);
		}

		// End the increment block with jump back to cond
		LLVMBuildBr(state.builder, forCond);

		// For out block
		LLVMMoveBasicBlockAfter(forOut, state.currentBlock);
		state.startBlock(forOut);
		state.replaceBreakBlock(saveBre);
		state.replaceContinueBlock(saveCon);

		return ContinueParent;
	}

	override Status visit(ir.ContinueStatement cs)
	{
		assert(state.currentContinueBlock !is null);

		if (cs.label !is null)
			throw CompilerPanic(cs.location, "labled continue statements not supported");

		LLVMBuildBr(state.builder, state.currentContinueBlock);
		state.currentFall = false;

		return Continue;
	}

	override Status visit(ir.BreakStatement bs)
	{
		assert(state.currentBreakBlock !is null);

		if (bs.label !is null)
			throw CompilerPanic(bs.location, "labled break statements not supported");

		LLVMBuildBr(state.builder, state.currentBreakBlock);
		state.currentFall = false;

		return Continue;
	}

	void doNewBlock(LLVMBasicBlockRef b, ir.BlockStatement bs,
	                LLVMBasicBlockRef fall)
	{
		LLVMMoveBasicBlockAfter(b, state.currentBlock);
		state.startBlock(b);
		accept(bs, this);
		if (state.currentFall)
			LLVMBuildBr(state.builder, fall);
	}


	/*
	 * Ignore but pass.
	 */
	override Status enter(ir.Module m) { return Continue; }
	override Status leave(ir.Module m) { return Continue; }

	/*
	 * Should not enter.
	 */
	override Status leave(ir.Variable v) { assert(false); }
	override Status leave(ir.Function fn) { assert(false); }
	override Status leave(ir.IfStatement i) { assert(false); }
	override Status leave(ir.ExpStatement e) { assert(false); }
	override Status leave(ir.ReturnStatement r) { assert(false); }
}
