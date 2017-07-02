// Copyright © 2014-2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.cfg;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.interfaces;
import volt.errors;
import volt.token.location;
import volt.visitor.visitor;
import volt.visitor.scopemanager;

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

/*!
 * Builds and checks CFGs on Functions.
 *
 * @ingroup passes passLang passSem
 */
class CFGBuilder : ScopeManager, Pass
{
public:
	LanguagePass lp;
	Block[] blocks;
	Block[] breakBlocks;
	ir.SwitchStatement currentSwitchStatement;
	Block[] currentSwitchBlocks;
	int currentCaseIndex = -1;
	ir.Class[] classStack;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	@property Block block(Block b)
	{
		assert(blocks.length > 0);
		return blocks[$-1] = b;
	}

	//! Returns the last block added.
	@property Block block()
	{
		assert(blocks.length > 0);
		return blocks[$-1];
	}

	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close()
	{
		blocks = null;
		return;
	}

	override Status enter(ir.Function func)
	{
		super.enter(func);
		if (func._body !is null) {
			blocks ~= new Block();  // Note: no parents.
		}
		return Continue;
	}

	override Status leave(ir.Function func)
	{
		super.leave(func);
		if (func._body is null) {
			return Continue;
		}
		ensureNonNullBlock(func.loc);
		if (block.canReachEntry()) {
			if (isVoid(realType(func.type.ret))) {
				buildReturnStat(func.loc, func._body);
			} else {
				throw makeExpected(func.loc, "return statement");
			}
		}

		if (func.kind == ir.Function.Kind.Constructor && block.canReachWithoutSuper() &&
		    classStack.length > 0) {
			panicAssert(func, classStack.length > 0);
			auto pclass = classStack[$-1].parentClass;
			if (pclass !is null) {
				bool noArgumentCtor;
				foreach (ctor; pclass.userConstructors) {
					if (ctor.type.params.length == 0) {
						panicAssert(ctor, !noArgumentCtor);
						noArgumentCtor = true;
						ir.Variable dummy;
						auto v = func.thisHiddenParameter;
						panicAssert(func, v !is null);
						ir.Exp tv = buildExpReference(v.loc, v, v.name);
						tv = buildCastSmart(tv.loc, buildVoidPtr(tv.loc), tv);
						auto call = buildCall(func.loc, buildExpReference(func.loc, ctor, ctor.name), [tv]);
						panicAssert(ctor, ctor._body !is null);
						func._body.statements = buildExpStat(func.loc, call) ~ func._body.statements;
						break;
					}
				}
				if (!noArgumentCtor) {
					throw makeNoSuperCall(func.loc);
				}
			}
		}

		blocks = blocks[0 .. $-1];
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
			ensureNonNullBlock(eref.loc);
			block.superCall = eref.isSuperOrThisCall;
		}
		return Continue;
	}

	//! Generate blocks from an if statement.
	override Status enter(ir.IfStatement ifs)
	{
		// TODO: This chokes on nested ifs -- break it up, and don't do it all at once.
		ensureNonNullBlock(ifs.loc);
		checkReachability(ifs);
		auto currentBlock = block;
		auto thenBlock = block = new Block(currentBlock);
		Block elseBlock;
		accept(ifs.thenState, this);
		if (ifs.elseState !is null) {
			elseBlock = block = new Block(currentBlock);
			accept(ifs.elseState, this);
			size_t terminateCount;
			foreach (child; elseBlock.children) {
				if (child.terminates) {
					terminateCount++;
				}
			}
			if (terminateCount == elseBlock.children.length && !elseBlock.terminates) {
				elseBlock.terminates = true;
			}
		}
		if (elseBlock !is null) {
			if (constantTrue(ifs.exp)) {
				block = new Block(thenBlock);
			} else if (constantFalse(ifs.exp)) {
				block = new Block(elseBlock);
			} else {
				block = new Block(thenBlock, elseBlock);
			}
		} else {
			if (constantTrue(ifs.exp)) {
				block = new Block(thenBlock);
			} else if (constantFalse(ifs.exp)) {
				block = new Block(currentBlock);
			} else {
				block = new Block(currentBlock, thenBlock);
			}
		}
		return ContinueParent;
	}

	override Status enter(ir.WhileStatement ws)
	{
		checkReachability(ws);
		enterLoop();
		return buildLoop(ws, ws.block, ws.condition);
	}

	override Status enter(ir.ForStatement fs)
	{
		checkReachability(fs);
		enterLoop();
		return buildLoop(fs, fs.block, fs.test);
	}

	override Status enter(ir.ForeachStatement fes)
	{
		ensureNonNullBlock(fes.loc);
		checkReachability(fes);
		enterLoop();
		auto currentBlock = block;
		auto fesBlock = block = new Block(currentBlock);
		breakBlocks ~= fesBlock;
		accept(fes.block, this);
		breakBlocks = breakBlocks[0 .. $-1];
		block = new Block(fesBlock);
		return ContinueParent;
	}

	override Status enter(ir.DoStatement ds)
	{
		ensureNonNullBlock(ds.loc);
		checkReachability(ds);
		enterLoop();
		auto currentBlock = block;
		auto doBlock = block = new Block(currentBlock);
		breakBlocks ~= doBlock;
		accept(ds.block, this);
		breakBlocks = breakBlocks[0 .. $-1];
		block = new Block(doBlock);
		return ContinueParent;
	}

	override Status enter(ir.LabelStatement ls)
	{
		ensureNonNullBlock(ls.loc);
		auto currentBlock = block;
		block = new Block(currentBlock);
		foreach (statement; ls.childStatement) {
			accept(statement, this);
		}
		return ContinueParent;
	}

	override Status enter(ir.SwitchStatement ss)
	{
		ensureNonNullBlock(ss.loc);
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
			throw makeExpected(ss.loc, "at least one case with a body");
		}

		foreach (i, _case; ss.cases) {
			currentCaseIndex = cast(int) i;
			breakBlocks ~= currentSwitchBlocks[i];
			block = currentSwitchBlocks[i];
			accept(_case.statements, this);
			currentSwitchBlocks[i] = block;
			if (block.canReachWithoutBreakGoto() && _case.statements.statements.length > 0 && block.canReachEntry() && i < ss.cases.length - 1) {
				throw makeCaseFallsThrough(_case.loc);
			}
			breakBlocks = breakBlocks[0 .. $-1];
		}

		block = new Block();
		size_t parents;
		foreach (i, _block; currentSwitchBlocks) {
			if ((i == currentSwitchBlocks.length - 1) &&
			    _block.canReachWithoutBreakGoto() &&
			    _block.canReachEntry()) {
				// The last case in a switch can omit a break. Insert it.
				ss.cases[i].statements.statements ~= buildBreakStatement(ss.cases[i].loc);
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
			throw makeMisplacedContinue(cs.loc);
		}
		ensureNonNullBlock(cs.loc);
		checkReachability(cs);
		if (cs.label.length > 0) {
			throw panic(cs.loc, "labelled continue unimplemented");
		}
		block.parents ~= block;
		block._break = true;
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		super.enter(c);
		classStack ~= c;
		return Continue;
	}

	override Status leave(ir.Class c)
	{
		super.leave(c);
		panicAssert(c, classStack.length > 0 && classStack[$-1] is c);
		classStack = classStack[0 .. $-1];
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
			throw makeGotoOutsideOfSwitch(gs.loc);
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
			throw makeNoDefaultCase(gs.loc);
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
				throw makeNoNextCase(gs.loc);
			}
			block.addChild(currentSwitchBlocks[i + 1]);
			currentSwitchBlocks[i + 1].addParent(block);
		} else {
			throw panic(gs.loc, "invalid goto statement.");
		}
		return Continue;
	}

	//! Generate blocks from a try statement.
	override Status enter(ir.TryStatement ts)
	{
		ensureNonNullBlock(ts.loc);
		checkReachability(ts);
		auto currentBlock = block;
		auto tryBlock = new Block(currentBlock);
		accept(ts.tryBlock, this);
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
		block = new Block();
		if (finallyBlock !is null) {
			block.addParent(finallyBlock);
		} else {
			block.addParents(catchBlocks);
			block.addParent(catchAll);
			block.addParent(tryBlock);
		}
		return ContinueParent;
	}

	override Status enter(ir.ThrowStatement ts)
	{
		ensureNonNullBlock(ts.loc);
		checkReachability(ts);
		block.terminates = true;
		return Continue;
	}

	override Status enter(ir.AssertStatement as)
	{
		if (as.isStatic) {
			return Continue;
		}
		block.terminates = constantFalse(as.condition);
		return Continue;
	}

	override Status visit(ir.BreakStatement bs)
	{
		if (breakBlocks.length == 0) {
			throw makeBreakOutOfLoop(bs.loc);
		}
		checkReachability(bs);
		block._break = true;
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
	bool constantTrue(ref ir.Exp e)
	{
		auto constant = evaluateOrNull(lp, current, e);
		if (constant is null) {
			return false;
		}
		e = constant;
		return constant.u._pointer !is null;
	}

	//! Returns true if the given expression evaluates as a constant false.
	bool constantFalse(ir.Exp e)
	{
		auto constant = evaluateOrNull(lp, current, e);
		if (constant is null) {
			return false;
		}
		return constant.u._pointer is null;
	}

	//! Convenience function for building blocks for loops.
	Status buildLoop(ir.Node n, ir.BlockStatement b, ir.Exp exp)
	{
		ensureNonNullBlock(n.loc);
		auto currentBlock = block;
		auto loopBlock = block = new Block(currentBlock);
		breakBlocks ~= loopBlock;
		accept(b, this);
		breakBlocks = breakBlocks[0 .. $-1];
		if (exp !is null && constantTrue(exp)) {
			block = new Block(loopBlock);
		} else if (exp !is null && constantFalse(exp)) {
			block = new Block(currentBlock);
		} else {
			block = new Block(currentBlock, loopBlock);
		}
		return ContinueParent;
	}

	void checkReachability(ir.Node n)
	{
		if (block.terminates) {
			throw makeNotReached(n);
		}
	}

	//! Sanity check function.
	void ensureNonNullBlock(ref in Location loc)
	{
		if (blocks.length == 0 || blocks[$-1] is null) {
			throw panic(loc, "invalid layout");
		}
	}
}

