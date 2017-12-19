/*#D*/
// Copyright © 2012-2017, Bernard Helyer.
// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Code that removes volt version constructs.
 *
 * @ingroup passPost
 */
module volta.postparse.condremoval;

import ir = volta.ir;
import vi = volta.visitor;

import volta.errors;
import volta.interfaces;
import volta.util.sinks;


/*!
 * A pass that removes version and debug blocks, not static ifs.
 *
 * @ingroup passes passLang passPost
 */
class ConditionalRemoval : vi.NullVisitor
{
private:
	ErrorSink mErr;
	VersionSet mVer;


public:
	this(ErrorSink es, VersionSet ver)
	{
		this.mErr = es;
		this.mVer = ver;
	}


	/*
	 *
	 * Visitor functions.
	 *
	 */

	override Status enter(ir.TopLevelBlock tlb)
	{
		tlb.nodes = manip(tlb.nodes);
		return vi.VisitorContinue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		bs.statements = manip(bs.statements);
		return vi.VisitorContinue;
	}

	// @TODO HACK Once attribute removal code is merged to
	// PostParsePass change visitor and remove this code.
	override Status enter(ir.Attribute a)
	{
		if (a.members !is null) {
			a.members.nodes = manip(a.members.nodes);
		}
		return Continue;
	}

	override Status enter(ir.Condition c)
	{
		if (c.kind != ir.Condition.Kind.StaticIf) {
			return Continue;
		}
		mErr.panic(c, "should not find condition here");
		return Continue;
	}

	override Status visit(ir.TemplateDefinition td)
	{
		if (td._struct !is null) {
			return vi.accept(td._struct, this);
		}
		if (td._union !is null) {
			return vi.accept(td._union, this);
		}
		if (td._interface !is null) {
			return vi.accept(td._interface, this);
		}
		if (td._class !is null) {
			return vi.accept(td._class, this);
		}
		if (td._function !is null) {
			return vi.accept(td._function, this);
		}

		mErr.panic("Invalid TemplateDefinition");
		return Continue;
	}


	/*
	 *
	 * Helper functions.
	 *
	 */

	bool evaluate(ir.ConditionStatement condstat, out ir.Node[] ret)
	{
		// We don't touch static ifs here.
		if (condstat.condition.kind == ir.Condition.Kind.StaticIf) {
			return false;
		}

		// Conditional Statement.
		if (evaluateCondition(condstat.condition)) {
			if (condstat.block !is null) {
				ret = condstat.block.statements;
			}
		} else {
			if (condstat._else !is null) {
				ret = condstat._else.statements;
			}
		}

		return true;
	}

	bool evaluate(ir.ConditionTopLevel cond, out ir.Node[] ret)
	{
		// We don't touch static ifs here.
		if (cond.condition.kind == ir.Condition.Kind.StaticIf) {
			return true;
		}

		// Conditional Top Level.
		if (evaluateCondition(cond.condition)) {
			if (cond.members !is null) {
				ret = cond.members.nodes;
			}
		} else {
			if (cond._else !is null) {
				ret = cond._else.nodes;
			}
		}

		return true;
	}


private:
	/*
	 *
	 * Manip flattening code.
	 *
	 */

	ir.Node[] manip(ir.Node[] nodes)
	{
		NodeSink ns;
		handle(/*#ref*/ ns, nodes);
		return ns.toArray();
	}

	void handle(ref NodeSink ns, ir.Node[] nodes)
	{
		ir.Node[] ret;
		foreach (n; nodes) {
			if (handle(/*#ref*/ ns, n, /*#out*/ ret)) {
				handle(/*#ref*/ ns, ret);
			} else {
				ns.sink(n);
			}
		}
	}

	bool handle(ref NodeSink ns, ir.Node n, out ir.Node[] ret)
	{
		ir.Node[] nodes;

		switch (n.nodeType) with (ir.NodeType) {
		case ConditionTopLevel:
			auto c = n.toConditionTopLevelFast();
			return evaluate(c, /*#out*/ ret);
		case ConditionStatement:
			auto c = n.toConditionStatementFast();
			return evaluate(c, /*#out*/ ret);
		case Unittest:
			// @TODO we currently just remove them.
			return true;
		default:
			// Make caller add this node.
			return false;
		}
	}


	/*
	 *
	 * Internal evaluation code.
	 *
	 */

	bool evaluateCondition(ir.Condition c)
	{
		if (c.kind == ir.Condition.Kind.Debug) {
			return mVer.debugEnabled;
		}
		bool[] stack;
		evaluateCondition(c, c.exp, /*#ref*/stack);
		passert(mErr, c, stack.length == 1);
		return stack[0];
	}

	void evaluateCondition(ir.Condition c, ir.Exp e, ref bool[] stack)
	{
		switch (e.nodeType) with (ir.NodeType) {
		case IdentifierExp:
			auto i = cast(ir.IdentifierExp) e;
			passert(mErr, c, i !is null);
			if (c.kind == ir.Condition.Kind.Version) {
				stack ~= mVer.isVersionSet(i.value);
			} else if (c.kind == ir.Condition.Kind.Debug) {
				stack ~= mVer.isDebugSet(i.value);
			} else {
				mErr.panic(e, "should not enter this path.");
				return;
			}
			return;
		case Unary:
			auto u = cast(ir.Unary) e;
			passert(mErr, c, u !is null);
			if (u.op != ir.Unary.Op.Not) {
				goto default;
			}
			evaluateCondition(c, u.value, /*#ref*/stack);
			if (stack.length == 0) {
				goto default;
			}
			stack[$-1] = !stack[$-1];
			return;
		case BinOp:
			auto b = cast(ir.BinOp) e;
			passert(mErr, c, b !is null);
			evaluateCondition(c, b.right, /*#ref*/stack);
			evaluateCondition(c, b.left, /*#ref*/stack);
			if (stack.length < 2) {
				goto default;
			}
			auto l = stack[$-1];
			auto r = stack[$-2];
			stack = stack[0 .. $-2];
			if (b.op == ir.BinOp.Op.AndAnd) {
				stack ~= l && r;
			} else if (b.op == ir.BinOp.Op.OrOr) {
				stack ~= l || r;
			} else {
				goto default;
			}
			return;
		default:
			mErr.errorExpected(e, "identifier, &&, ||, (), or !");
			return;
		}
	}
}
