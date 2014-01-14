// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.toplevel;

import lib.llvm.core;

import volt.errors;
import volt.visitor.visitor;
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
		auto ct = cast(CallableType)type;
		assert(ct !is null);

		auto oldFall = state.currentFall;
		auto oldFunc = state.currentFunc;
		auto oldBlock = state.currentBlock;

		state.currentFall = true;
		state.currentFunc = llvmFunc;
		state.currentBlock = LLVMAppendBasicBlock(llvmFunc, "entry");
		LLVMPositionBuilderAtEnd(b, state.currentBlock);

		if (fn.kind == ir.Function.Kind.GlobalConstructor) {
			state.globalConstructors ~= llvmFunc;
		} else if (fn.kind == ir.Function.Kind.GlobalDestructor) {
			state.globalDestructors ~= llvmFunc;
		} else if (fn.kind == ir.Function.Kind.LocalConstructor) {
			state.localConstructors ~= llvmFunc;
		} else if (fn.kind == ir.Function.Kind.LocalDestructor) {
			state.localDestructors ~= llvmFunc;
		}

		foreach(uint i, p; fn.params) {
			if (p.name is null)
				continue;

			auto v = LLVMGetParam(llvmFunc, i);

			ir.StorageType.Kind dummy;
			if (volt.semantic.classify.isRef(p.type, dummy)) {
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

		foreach(n; fn._body.statements)
			accept(n, this);

		// Assume language pass knows what it is doing.
		if (state.currentFall) {
			LLVMBuildCall(state.builder, state.llvmTrap, null);
			LLVMBuildUnreachable(state.builder);
		}

		state.currentFall = oldFall;
		state.currentFunc = oldFunc;
		state.currentBlock = oldBlock;

		// Reset builder for nested functions.
		if (state.currentBlock !is null) {
			LLVMPositionBuilderAtEnd(b, state.currentBlock);
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
			assert(state.currentFunc !is null);

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
				init = state.getConstant(var.assign);
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

	override Status enter(ir.SwitchStatement ss)
	{
		assert(state.currentFall);

		auto cond = state.getValue(ss.condition);

		struct Block
		{
			ir.SwitchCase _case;
			LLVMBasicBlockRef block;
		}
		Block[] blocks;

		auto oldCases = state.currentSwitchCases; 
		auto oldDefault = state.currentSwitchDefault;
		state.currentSwitchCases = null;
		// Even final switches have an (invalid) default case.
		state.currentSwitchDefault = LLVMAppendBasicBlockInContext(state.context, state.currentFunc, "defaultCase");
		ir.BlockStatement defaultStatements;
		auto _switch = LLVMBuildSwitch(state.builder, cond, state.currentSwitchDefault, cast(uint)(ss.cases.length));

		foreach (_case; ss.cases) {
			if (_case.firstExp !is null) acceptExp(_case.firstExp, this);
			void addVal(LLVMValueRef val, LLVMBasicBlockRef block)
			{
				auto i = LLVMConstIntGetSExtValue(val);
				if ((i in state.currentSwitchCases) !is null) {
					throw makeSwitchDuplicateCase(_case);
				} else {
					state.currentSwitchCases[i] = block;
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
				auto block = LLVMAppendBasicBlockInContext(state.context, state.currentFunc, "switchCase");
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
						auto val = LLVMConstInt(typ, ai++, false); 
						addVal(val, block);
					}
				} else {
					addExp(_case.firstExp, block);
					foreach (exp; _case.exps) addExp(exp, block);
				}
				blocks ~= Block(_case, block);
			}
		}
		auto outBlock = LLVMAppendBasicBlockInContext(state.context, state.currentFunc, "endSwitch");

		// Generate code for each case.
		auto breakBlock = state.replaceBreakBlock(outBlock);
		foreach (i, block; blocks) {
			state.startBlock(block.block);
			doNewBlock(block.block, block._case.statements, i == blocks.length - 1 ? outBlock : blocks[i+1].block);
		}
		state.startBlock(state.currentSwitchDefault);
		if (defaultStatements !is null) {
			doNewBlock(state.currentSwitchDefault, defaultStatements, outBlock);
		} else {
			// No default block (e.g. final switches)
			LLVMBuildCall(state.builder, state.llvmTrap, null);
			LLVMBuildUnreachable(state.builder);
		}
		state.replaceBreakBlock(breakBlock);

		// Continue generating code after the switch.
		LLVMMoveBasicBlockAfter(outBlock, state.currentBlock);
		state.startBlock(outBlock);

		state.currentSwitchDefault = oldDefault;
		state.currentSwitchCases = oldCases;

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
			throw panic(cs.location, "labled continue statements not supported");

		LLVMBuildBr(state.builder, state.currentContinueBlock);
		state.currentFall = false;

		return Continue;
	}

	override Status visit(ir.BreakStatement bs)
	{
		assert(state.currentBreakBlock !is null);

		if (bs.label !is null)
			throw panic(bs.location, "labled break statements not supported");

		LLVMBuildBr(state.builder, state.currentBreakBlock);
		state.currentFall = false;

		return Continue;
	}

	override Status leave(ir.GotoStatement gs)
	{
		if (!gs.isDefault && !gs.isCase) {
			throw panic(gs.location, "non switch goto");
		}
		throw makeExpected(gs.location, "break or return ending case.");
	}

	override Status leave(ir.ThrowStatement t)
	{
		if (t.exp is null) {
			throw panic(t.location, "empty throw statement");
		}
	
		state.getValue(t.exp);
		LLVMBuildUnreachable(state.builder);
		state.currentFall = false;

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
				int priority = 1;
				if (m.name.strings == ["vrt", "vmain"]) {
					priority = 2;
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

	/*
	 * Should not enter.
	 */
	override Status leave(ir.Variable v) { assert(false); }
	override Status leave(ir.Function fn) { assert(false); }
	override Status leave(ir.IfStatement i) { assert(false); }
	override Status leave(ir.ExpStatement e) { assert(false); }
	override Status leave(ir.ReturnStatement r) { assert(false); }
}
