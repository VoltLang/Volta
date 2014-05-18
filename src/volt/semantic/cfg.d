module volt.semantic.cfg;

import volt.interfaces;
import volt.errors;
import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.token.location;
import volt.semantic.classify;
import volt.semantic.typer;
import volt.semantic.ctfe;
import ir = volt.ir.ir;
import volt.ir.util;

/// A single node in the execution graph.
class Block
{
public:
	Block[] parents;  ///< Where execution could come from.
	Block[] children;

private:
	bool mTerminates;  ///< Running this block ends execution of its function (e.g. return).

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

	@property void terminates(bool b)
	{
		mTerminates = b;
	}

	@property bool terminates()
	{
		return mTerminates;
	}
}

/// Returns true if the given block can reach its function's entry point.
bool canReachEntry(Block block)
{
	if (block.terminates) {
		return false;
	}
	if (block.parents.length == 0) {
		return true;
	}
	foreach (parent; block.parents) {
		if (canReachEntry(parent)) {
			return true;
		}
	}
	return false;
}

/// Builds and checks CFGs on Functions.
class CFGBuilder : ScopeManager, Pass
{
public:
	LanguagePass lp;
	Block[] blocks;
	Block[] breakBlocks;

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

	/// Returns the last block added.
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
		blocks.length = 0;
		return;
	}

	override Status enter(ir.Function fn)
	{
		super.enter(fn);
		if (fn._body !is null) {
			blocks ~= new Block();  // Note: no parents.
		}
		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		super.leave(fn);
		if (fn._body is null) {
			return Continue;
		}
		ensureNonNullBlock(fn.location);
		if (canReachEntry(block)) {
			if (isVoid(realType(fn.type.ret))) {
				buildReturnStat(fn.location, fn._body);
			} else {
				throw makeExpected(fn.location, "return statement");
			}
		}

		blocks = blocks[0 .. $-1];
		return Continue;
	}

	override Status enter(ir.ReturnStatement rs)
	{
		if (block.terminates) {
			// error!
		}
		block.terminates = true;
		return Continue;
	}

	/// Generate blocks from an if statement.
	override Status enter(ir.IfStatement ifs)
	{
		ensureNonNullBlock(ifs.location);
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
		return buildLoop(ws, ws.block, ws.condition);
	}

	override Status enter(ir.ForStatement fs)
	{
		return buildLoop(fs, fs.block, fs.test);
	}

	override Status enter(ir.ForeachStatement fes)
	{
		throw panic(fes.location, "foreach after extyper");
	}

	override Status enter(ir.DoStatement ds)
	{
		ensureNonNullBlock(ds.location);
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
		ensureNonNullBlock(ls.location);
		auto currentBlock = block;
		block = new Block(currentBlock);
		foreach (statement; ls.childStatement) {
			accept(statement, this);
		}
		return ContinueParent;
	}

	override Status enter(ir.SwitchStatement ss)
	{
		ensureNonNullBlock(ss.location);
		auto currentBlock = block;
		auto caseBlocks = new Block[](ss.cases.length);
		foreach (i, _case; ss.cases) {
			if (_case.statements.statements.length == 0) {
				continue;
			}
			block = new Block(currentBlock);
			breakBlocks ~= block;
			accept(_case.statements, this);
			breakBlocks = breakBlocks[0 .. $-1];
			caseBlocks[i] = block;
		}
		block = new Block(caseBlocks);
		return ContinueParent;
	}

	override Status visit(ir.ContinueStatement cs)
	{
		ensureNonNullBlock(cs.location);
		if (cs.label.length > 0) {
			throw panic(cs.location, "labelled continue unimplemented");
		}
		block.parents ~= block;
		return Continue;
	}

	override Status enter(ir.GotoStatement gs)
	{
		throw panic(gs.location, "goto statement unimplemented");
	}

	/// Generate blocks from a try statement.
	override Status enter(ir.TryStatement ts)
	{
		ensureNonNullBlock(ts.location);
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
		ensureNonNullBlock(ts.location);
		block.terminates = true;
		return Continue;
	}

	override Status enter(ir.AssertStatement as)
	{
		if (as.isStatic) {
			return Continue;
		}
		block.terminates = constantTrue(as.condition);
		return Continue;
	}

	override Status visit(ir.BreakStatement bs)
	{
		if (breakBlocks.length == 0) {
			throw makeBreakOutOfLoop(bs.location);
		}
		return Continue;
	}


private:

	/// Returns true if the given expression evaluates as a constant true.
	bool constantTrue(ir.Exp e)
	{
		auto constant = evaluateOrNull(lp, current, e);
		if (constant is null) {
			return false;
		}
		return constant._pointer !is null;
	}

	/// Returns true if the given expression evaluates as a constant false.
	bool constantFalse(ir.Exp e)
	{
		auto constant = evaluateOrNull(lp, current, e);
		if (constant is null) {
			return false;
		}
		return constant._pointer is null;
	}

	/// Convenience function for building blocks for loops.
	Status buildLoop(ir.Node n, ir.BlockStatement b, ir.Exp exp)
	{
		ensureNonNullBlock(n.location);
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

	/// Sanity check function.
	void ensureNonNullBlock(Location l)
	{
		if (blocks.length == 0 || blocks[$-1] is null) {
			throw panic(l, "invalid layout");
		}
	}
}

