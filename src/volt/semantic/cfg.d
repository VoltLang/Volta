/*#D*/
// Copyright © 2014-2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.cfg;

import watt.containers.stack;

import ir = volta.ir;
import volta.util.util;

import volt.interfaces;
import volt.errors;
import volta.ir.location;
import volta.visitor.visitor;
import volta.visitor.scopemanager;
import volta.util.stack;

import volt.semantic.evaluate;
import volt.semantic.classify;

//! A single node in the execution graph.
class Block
{
public:
	Block[] parents;  //!< Where execution could come from.
	Block[] children;
	bool superCall;  //!< For handling super calls in ctors.
	bool terminates;  //!< Running this block ends execution of its function (e.g. return).
	bool _goto, _break; //!< For handling switches, did this case have a goto or break?
	bool broken;  //!< For loop bodies; did a break block occur while this was the top of the breakBlock stack?

public:
	this()
	{
	}

	this(Block parent)
	{
		addParent(parent);
	}

	this(Block[] parents...)
	{
		addParents(parents);
	}

	void addParent(Block parent)
	{
		if (parent is null) {
			return;
		}
		parents ~= parent;
		parent.addChild(this);
	}

	void addChild(Block child)
	{
		children ~= child;
	}

	void addParents(Block[] parents)
	{
		foreach (parent; parents) {
			addParent(parent);
		}
	}

	bool canReachEntry()
	{
		bool term(Block b) { return b.terminates; }
		version (Volt) return canReachWithout(this, term);
		else return canReachWithout(this, &term);
	}

	bool canReachWithoutBreakGoto()
	{
		bool term(Block b) { return b._break || b._goto; }
		version (Volt) return canReachWithout(this, term);
		else return canReachWithout(this, &term);
	}

	bool canReachWithoutSuper()
	{
		bool term(Block b) { return b.superCall; }
		version (Volt) return canReachWithout(this, term);
		else return canReachWithout(this, &term);
	}

	bool hitsBreakBeforeTarget(Block target)
	{
		assert(this !is target);
		bool term(Block b) { return b._break; }
		version (Volt) return canReachChildBefore(this, term, target);
		else return canReachChildBefore(this, &term, target);
	}
}

//! Returns true if the given block can reach the entry without dgt returning true.
bool canReachWithout(Block block, bool delegate(Block) dgt)
{
	if (dgt(block)) {
		return false;
	}
	if (block.parents.length == 0) {
		return true;
	}
	foreach (parent; block.parents) {
		if (canReachWithout(parent, dgt)) {
			return true;
		}
	}
	return false;
}

bool canReachChildBefore(Block block, bool delegate(Block) dgt, Block target)
{
	if (dgt(block)) {
		return true;
	}
	if (block is target) {
		return false;
	}
	foreach (child; block.children) {
		if (canReachChildBefore(child, dgt, target)) {
			return true;
		}
	}
	return false;
}

alias BlockStack = Stack!Block;

/*!
 * Builds and checks CFGs on Functions.
 *
 * @ingroup passes passLang passSem
 */
class CFGBuilder : ScopeManager, Pass
{
public:
	LanguagePass lp;
	BlockStack blocks;
	BlockStack breakBlocks;
	ir.SwitchStatement currentSwitchStatement;
	Block[] currentSwitchBlocks;
	int currentCaseIndex = -1;
	ClassStack classStack;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
		super(lp.errSink);
	}

	@property Block block(Block b)
	{
		assert(blocks.length > 0);
		blocks.pop();
		blocks.push(b);
		return b;
	}

	//! Returns the last block added.
	@property Block block()
	{
		assert(blocks.length > 0);
		return blocks.peek();
	}

	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close()
	{
		blocks.clear();
		return;
	}

	override Status enter(ir.Function func)
	{
		super.enter(func);
		if (func.hasBody) {
			blocks.push(new Block());  // Note: no parents.
		}
		return Continue;
	}

	override Status leave(ir.Function func)
	{
		super.leave(func);
		if (!func.hasBody) {
			return Continue;
		}

		panicAssert(func, func.parsedBody !is null);

		ensureNonNullBlock(/*#ref*/func.loc);
		if (func.loc.filename == "test.volt") {
		}
		if (block.canReachEntry()) {
			if (isVoid(realType(func.type.ret))) {
				buildReturnStat(/*#ref*/func.loc, func.parsedBody);
			} else {
				throw makeExpected(/*#ref*/func.loc, "return statement");
			}
		}

		if (func.kind == ir.Function.Kind.Constructor && block.canReachWithoutSuper() &&
		    classStack.length > 0) {
			panicAssert(func, classStack.length > 0);
			auto pclass = classStack.peek().parentClass;
			if (pclass !is null) {
				bool noArgumentCtor;
				foreach (ctor; pclass.userConstructors) {
					if (ctor.type.params.length == 0) {
						panicAssert(ctor, !noArgumentCtor);
						noArgumentCtor = true;
						ir.Variable dummy;
						auto v = func.thisHiddenParameter;
						panicAssert(func, v !is null);
						ir.Exp tv = buildExpReference(/*#ref*/v.loc, v, v.name);
						tv = buildCastSmart(/*#ref*/tv.loc, buildVoidPtr(/*#ref*/tv.loc), tv);
						auto call = buildCall(/*#ref*/func.loc, buildExpReference(/*#ref*/func.loc, ctor, ctor.name), [tv]);
						panicAssert(ctor, ctor.parsedBody !is null);
						func.parsedBody.statements = buildExpStat(/*#ref*/func.loc, call) ~ func.parsedBody.statements;
						break;
					}
				}
				if (!noArgumentCtor) {
					throw makeNoSuperCall(/*#ref*/func.loc);
				}
			}
		}

		blocks.pop();
		return Continue;
	}

	override Status enter(ir.ReturnStatement rs)
	{
		checkReachability(rs);
		block.terminates = true;
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.StatementExp se)
	{
		// Trust that the StatementExp is sane.
		return ContinueParent;
	}

	override Status enter(ir.ExpStatement es)
	{
		checkReachability(es);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.ExpReference eref)
	{
		if (eref.isSuperOrThisCall) {
			ensureNonNullBlock(/*#ref*/eref.loc);
			block.superCall = eref.isSuperOrThisCall;
		}
		return Continue;
	}

	//! Generate blocks from an if statement.
	override Status enter(ir.IfStatement ifs)
	{
		ensureNonNullBlock(/*#ref*/ifs.loc);
		checkReachability(ifs);
		auto currentBlock = block;
		auto thenBlock = block = new Block(currentBlock);
		Block elseBlock;
		accept(ifs.thenState, this);
		thenBlock = block;
		if (ifs.elseState !is null) {
			elseBlock = block = new Block(currentBlock);
			accept(ifs.elseState, this);
			elseBlock = block;
		}
		block = new Block();
		if (!constantFalse(ifs.exp) && !thenBlock._goto) {
			block.addParent(thenBlock);
		}
		if (elseBlock !is null) {
			if (!elseBlock._goto && !constantTrue(ifs.exp)) {
				block.addParent(elseBlock);
			}
		} else {
			if (!constantTrue(ifs.exp)) {
				block.addParent(currentBlock);
			}
		}
		if (block.parents.length == 0) {
			auto invalidBlock = new Block();
			invalidBlock.terminates = true;
			invalidBlock.addParent(currentBlock);
			block.addParent(invalidBlock);
		}
		return ContinueParent;
	}

	override Status enter(ir.ForStatement fs)
	{
		checkReachability(fs);
		enterLoop();
		return buildLoop(fs, fs.block, fs.test);
	}

	override Status enter(ir.ForeachStatement fes)
	{
		ensureNonNullBlock(/*#ref*/fes.loc);
		checkReachability(fes);
		enterLoop();
		auto currentBlock = block;
		auto fesBlock = block = new Block(currentBlock);
		breakBlocks.push(fesBlock);
		accept(fes.block, this);
		breakBlocks.pop();
		block = new Block(fesBlock);
		return ContinueParent;
	}

	override Status enter(ir.WhileStatement ws)
	{
		checkReachability(ws);
		enterLoop();
		return buildLoop(ws, ws.block, ws.condition);
	}

	override Status enter(ir.DoStatement ds)
	{
		checkReachability(ds);
		enterLoop();
		return buildDoLoop(ds, ds.block, ds.condition);
	}

	override Status enter(ir.LabelStatement ls)
	{
		ensureNonNullBlock(/*#ref*/ls.loc);
		auto currentBlock = block;
		block = new Block(currentBlock);
		foreach (statement; ls.childStatement) {
			accept(statement, this);
		}
		return ContinueParent;
	}

	override Status enter(ir.SwitchStatement ss)
	{
		ensureNonNullBlock(/*#ref*/ss.loc);
		checkReachability(ss);
		auto oldSwitchBlocks = currentSwitchBlocks;
		auto oldSwitchStatement = currentSwitchStatement;
		auto oldCaseIndex = currentCaseIndex;
		currentSwitchBlocks = new Block[](ss.cases.length);
		currentSwitchStatement = ss;

		auto currentBlock = block;
		size_t empty;
		foreach (i, _case; ss.cases) {
			currentSwitchBlocks[i] = new Block(currentBlock);
			if (_case.statements.statements.length == 0) {
				/* If it's empty, consider it as terminating,
				 * except if it is the last case.
				 */
				currentSwitchBlocks[i].terminates =
					_case !is ss.cases[$-1];
				empty++;
			}
		}
		if (empty == ss.cases.length) {
			throw makeExpected(/*#ref*/ss.loc, "at least one case with a body");
		}

		foreach (i, _case; ss.cases) {
			currentCaseIndex = cast(int) i;
			breakBlocks.push(currentSwitchBlocks[i]);
			block = currentSwitchBlocks[i];
			accept(_case.statements, this);
			currentSwitchBlocks[i] = block;
			if (block.canReachWithoutBreakGoto() && _case.statements.statements.length > 0
				&& block.canReachEntry() && i < ss.cases.length - 1 && block.parents.length != 0) {
				throw makeCaseFallsThrough(/*#ref*/_case.loc);
			}
			breakBlocks.pop();
		}

		block = new Block();
		size_t parents;
		foreach (i, _block; currentSwitchBlocks) {
			if ((i == currentSwitchBlocks.length - 1) &&
			    _block.canReachWithoutBreakGoto() &&
			    _block.canReachEntry()) {
				// The last case in a switch can omit a break. Insert it.
				ss.cases[i].statements.statements ~= buildBreakStatement(/*#ref*/ss.cases[i].loc);
				_block._break = true;

			}
			if (currentBlock.hitsBreakBeforeTarget(_block) ||
			    ss.cases[i].statements.statements.length == 0) {
				block.addParent(_block);
				parents++;
			}

		}
		block.terminates = parents == 0;

		currentSwitchBlocks = oldSwitchBlocks;
		currentSwitchStatement = oldSwitchStatement;
		currentCaseIndex = oldCaseIndex;
		return ContinueParent;
	}

	override Status visit(ir.ContinueStatement cs)
	{
		if (mLoopDepth == 0) {
			throw makeMisplacedContinue(/*#ref*/cs.loc);
		}
		ensureNonNullBlock(/*#ref*/cs.loc);
		checkReachability(cs);
		if (cs.label.length > 0) {
			throw panic(/*#ref*/cs.loc, "labelled continue unimplemented");
		}
		block.parents ~= block;
		block._break = true;
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		super.enter(c);
		classStack.push(c);
		return Continue;
	}

	override Status leave(ir.Class c)
	{
		super.leave(c);
		panicAssert(c, classStack.length > 0 && classStack.peek() is c);
		classStack.pop();
		return Continue;
	}

	override Status enter(ir.GotoStatement gs)
	{
		Status addTarget(size_t i)
		{
			block.addChild(currentSwitchBlocks[i]);
			currentSwitchBlocks[i].addParent(block);
			return Continue;
		}

		if (currentSwitchStatement is null || currentCaseIndex < 0) {
			throw makeGotoOutsideOfSwitch(/*#ref*/gs.loc);
		}
		checkReachability(gs);
		block._goto = true;
		if (gs.isDefault) {
			// goto default;
			foreach (i, _case; currentSwitchStatement.cases) {
				if (_case.isDefault) {
					return addTarget(i);
				}
			}
			throw makeNoDefaultCase(/*#ref*/gs.loc);
		} else if (gs.isCase && gs.exp !is null) {
			// goto case foo;

			// Do we know the result now?
			auto _constant = evaluateOrNull(lp, current, gs.exp);
			auto currentIndex = cast(size_t) currentCaseIndex;
			if (_constant !is null) foreach (i, _case; currentSwitchStatement.cases) {
				auto firstConstant = evaluateOrNull(lp, current, _case.firstExp);
				if (firstConstant !is null && _constant.u._ulong == firstConstant.u._ulong) {
					return addTarget(i);
				}
				auto secondConstant = evaluateOrNull(lp, current, _case.secondExp);
				if (secondConstant !is null && _constant.u._ulong >= firstConstant.u._ulong && _constant.u._ulong < secondConstant.u._ulong) {
					return addTarget(i);
				}
				foreach (exp; _case.exps) {
					auto caseConst = evaluateOrNull(lp, current, _case.firstExp);
					if (caseConst !is null && _constant.u._ulong == caseConst.u._ulong) {
						return addTarget(i);
					}
				}
			}

			// If not, mark all possible targets.
			foreach (i, _case; currentSwitchStatement.cases) {
				if (_case.isDefault || i == currentIndex) {
					continue;
				}
				block.addChild(currentSwitchBlocks[i]);
				currentSwitchBlocks[i].addParent(block);
			}
		} else if (gs.isCase && gs.exp is null) {
			// goto case;
			auto i = cast(size_t) currentCaseIndex;
			if (i >= currentSwitchBlocks.length - 1) {
				throw makeNoNextCase(/*#ref*/gs.loc);
			}
			block.addChild(currentSwitchBlocks[i + 1]);
			currentSwitchBlocks[i + 1].addParent(block);
		} else {
			throw panic(/*#ref*/gs.loc, "invalid goto statement.");
		}
		return Continue;
	}

	//! Generate blocks from a try statement.
	override Status enter(ir.TryStatement ts)
	{
		ensureNonNullBlock(/*#ref*/ts.loc);
		checkReachability(ts);
		auto currentBlock = block;
		auto tryBlock = new Block(currentBlock);
		block = tryBlock;
		accept(ts.tryBlock, this);

		/* Consider the following:
		 * try {
		 *     return foo();  // This block marked as 'terminates'...
		 * } catch (Exception e) {
		 *     doAThing();    // ...but it can't be 'terminates' here...
		 * }
		 * doSomethingElse(); // ...but it can be 'terminates' here.
		 *
		 * So we delay marking it as terminates until after we've processed
		 * the catch blocks.
		 */
		bool tryTerminates = tryBlock.terminates;
		tryBlock.terminates = false;

		auto catchBlocks = new Block[](ts.catchBlocks.length);
		foreach (i, catchBlock; ts.catchBlocks) {
			catchBlocks[i] = block = new Block(tryBlock);
			accept(catchBlock, this);
		}
		Block catchAll;
		if (ts.catchAll !is null) {
			catchAll = block = new Block(tryBlock);
			accept(ts.catchAll, this);
		}
		Block finallyBlock;
		if (ts.finallyBlock !is null) {
			finallyBlock = block = new Block(catchBlocks);
			finallyBlock.addParent(catchAll);
			accept(ts.finallyBlock, this);
		}
		tryBlock.terminates = tryTerminates;
		block = new Block();
		if (finallyBlock !is null) {
			block.addParent(finallyBlock);
		} else {
			block.addParents(catchBlocks);
			block.addParent(catchAll);
			if (!tryBlock.terminates) {
				block.addParent(tryBlock);
			}
		}

		return ContinueParent;
	}

	override Status enter(ir.ThrowStatement ts)
	{
		ensureNonNullBlock(/*#ref*/ts.loc);
		checkReachability(ts);
		block.terminates = true;
		return Continue;
	}

	override Status enter(ir.AssertStatement as)
	{
		if (as.isStatic) {
			return Continue;
		}
		checkReachability(as);
		block.terminates = constantFalse(as.condition);
		return Continue;
	}

	override Status visit(ir.BreakStatement bs)
	{
		if (breakBlocks.length == 0) {
			throw makeBreakOutOfLoop(/*#ref*/bs.loc);
		}
		checkReachability(bs);
		block._break = true;
		breakBlocks.peek().broken = true;
		return Continue;
	}

	override Status leave(ir.WhileStatement ws)
	{
		leaveLoop();
		return Continue;
	}

	override Status leave(ir.DoStatement ds)
	{
		leaveLoop();
		return Continue;
	}

	override Status leave(ir.ForStatement fs)
	{
		leaveLoop();
		return Continue;
	}

	override Status leave(ir.ForeachStatement fs)
	{
		leaveLoop();
		return Continue;
	}


private:
	int mLoopDepth;

private:
	void enterLoop()
	{
		mLoopDepth++;
	}

	void leaveLoop()
	{
		mLoopDepth--;
		assert(mLoopDepth >= 0);
	}

	//! Returns true if the given expression evaluates as a constant true.
	bool constantTrue(ir.Exp e)
	{
		auto constant = evaluateOrNull(lp, current, e);
		if (constant is null) {
			return false;
		}
		return constant.u._bool;
	}

	//! Returns true if the given expression evaluates as a constant false.
	bool constantFalse(ir.Exp e)
	{
		auto constant = evaluateOrNull(lp, current, e);
		if (constant is null) {
			return false;
		}
		return !constant.u._bool;
	}

	//! Convenience function for building blocks for loops.
	Status buildLoop(ir.Node n, ir.BlockStatement b, ir.Exp exp)
	{
		ensureNonNullBlock(/*#ref*/n.loc);
		auto currentBlock = block;
		auto loopBlock = block = new Block(currentBlock);
		breakBlocks.push(loopBlock);
		accept(b, this);
		breakBlocks.pop();
		if (exp !is null && constantTrue(exp)) {
			block = new Block(loopBlock);
			if (!loopBlock.broken) {
				block.terminates = true;
			}
		} else if (exp !is null && constantFalse(exp)) {
			block = new Block(currentBlock);
		} else {
			block = new Block(currentBlock, loopBlock);
		}
		return ContinueParent;
	}

	//! Build a do loop. Could be done in `enter(DoStatement)`, but this is neater.
	Status buildDoLoop(ir.Node n, ir.BlockStatement b, ir.Exp exp)
	{
		ensureNonNullBlock(/*#ref*/n.loc);
		auto currentBlock = block;
		auto loopBlock = block = new Block(currentBlock);
		breakBlocks.push(loopBlock);
		accept(b, this);
		breakBlocks.pop();
		if (exp !is null && constantTrue(exp)) {
			block = new Block(loopBlock);
			if (!loopBlock.broken) {
				block.terminates = true;
			}
		} else {
			/* This is the major difference with `buildLoop`.  
			 * As long as the DW isn't an infinite loop (the
			 * previous if statement), the loopBlock itselfg
			 * is always a potential parent.
			 */
			block = new Block(currentBlock, loopBlock);
		}
		return ContinueParent;
	}

	void checkReachability(ir.Node n)
	{
		if (!block.canReachEntry()) {
			throw makeNotReached(n);
		}
	}

	//! Sanity check function.
	void ensureNonNullBlock(ref in Location loc)
	{
		if (blocks.length == 0 || blocks.peek() is null) {
			throw panic(/*#ref*/loc, "invalid layout");
		}
	}
}
