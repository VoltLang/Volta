/*#D*/
// Copyright © 2012-2017, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012-2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.postparse.pass;

import io = watt.io.std;

import ir = volta.ir;
import vi = volta.visitor;

import volta.errors;
import volta.interfaces;

import volta.util.sinks;
import volta.postparse.condremoval;


class PostParsePass : vi.NullVisitor, Pass
{
protected:
	ErrorSink mErr;
	ConditionalRemoval mCond;


public:
	this(ErrorSink es, VersionSet vs)
	{
		mErr = es;
		mCond = new ConditionalRemoval(es, vs);
	}

	override void transform(ir.Module mod)
	{
		vi.accept(mod, this);
	}

	override void close()
	{

	}


	/*
	 *
	 * Flattening code
	 *
	 */

	override Status enter(ir.TopLevelBlock tlb)
	{
		tlb.nodes = manip(tlb.nodes);
		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		bs.statements = manip(bs.statements);
		return Continue;
	}

	// @TODO HACK Once attribute removal code is merged here change visitor.
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
		assert(false);
	}

	override Status visit(ir.TemplateDefinition td)
	{
		// Need to switch over to pure CondRemoval code.

		if (td._struct !is null) {
			return vi.accept(td._struct, mCond);
		}
		if (td._union !is null) {
			return vi.accept(td._union, mCond);
		}
		if (td._interface !is null) {
			return vi.accept(td._interface, mCond);
		}
		if (td._class !is null) {
			return vi.accept(td._class, mCond);
		}
		if (td._function !is null) {
			return vi.accept(td._function, mCond);
		}

		mErr.panic(td, "Invalid TemplateDefinition");
		assert(false);
	}


	/*
	 *
	 * Manip flattening code code.
	 *
	 */

	final ir.Node[] manip(ir.Node[] nodes)
	{
		NodeSink ns;
		handle(/*#ref*/ ns, nodes);
		return ns.toArray();
	}

	final void handle(ref NodeSink ns, ir.Node[] nodes)
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

	final bool handle(ref NodeSink ns, ir.Node n, out ir.Node[] ret)
	{
		ir.Node[] nodes;

		switch (n.nodeType) with (ir.NodeType) {
		case ConditionTopLevel:
			auto c = n.toConditionTopLevelFast();
			return mCond.evaluate(c, /*#out*/ ret);
		case ConditionStatement:
			auto c = n.toConditionStatementFast();
			return mCond.evaluate(c, /*#out*/ ret);
		case Unittest:
			// @TODO we currently just remove them.
			return true;
		default:
			// Make caller add this node.
			return false;
		}
	}
}
