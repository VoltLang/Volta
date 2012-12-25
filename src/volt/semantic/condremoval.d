// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.condremoval;

import volt.exceptions;
import volt.interfaces;
import volt.ir.base;
import volt.visitor.manip;
import volt.visitor.visitor;

/**
 * A pass that removes version and debug blocks.
 *
 * @ingroup passes passLang
 */
class ConditionalRemoval : NullVisitor, Pass
{
public:
	Settings settings;

public:
	this(Settings settings)
	{
		this.settings = settings;
	}

public:
	bool evaluateCondition(ir.Condition c)
	{
		if (c.kind == ir.Condition.Kind.Version) {
			return settings.isVersionSet(c.identifier);
		} else if (c.kind == ir.Condition.Kind.Debug) {
			return settings.isDebugSet(c.identifier);
		} else {
			/// Static if.
			return false;
		}
	}

	/// Replace conditionals with their children, or not, depending on their Condition.
	bool removeConditionals(ir.Node node, out ir.Node[] ret)
	{
		if (auto cond = cast(ir.ConditionTopLevel) node) {
			// Conditional Top Level.
			if (evaluateCondition(cond.condition)) {
				ret = cond.members.nodes;
			} else {
				ret = cond._else.nodes;
			}
			if (ret.length > 0) {
				ret = manipNodes(ret, &removeConditionals);
			}
			return true;
		} else if (auto condstatement = cast(ir.ConditionStatement) node) {
			// Conditional Statement.
			if (evaluateCondition(condstatement.condition)) {
				ret = condstatement.block.statements;
			} else {
				ret = condstatement._else.statements;
			}
			if (ret.length > 0) {
				ret = manipNodes(ret, &removeConditionals);
			}
			return true;
		} else {
			// Not a Condition at all.
			return false;
		}
	}

public:
	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close() {}

	override Status enter(ir.Module m)
	{
		m.children.nodes = manipNodes(m.children.nodes, &removeConditionals);
		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		bs.statements = manipNodes(bs.statements, &removeConditionals);
		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		if (fn.inContract !is null) fn.inContract.statements = manipNodes(fn.inContract.statements, &removeConditionals);
		if (fn.outContract !is null) fn.outContract.statements = manipNodes(fn.outContract.statements, &removeConditionals);
		if (fn._body !is null) fn._body.statements = manipNodes(fn._body.statements, &removeConditionals);
		return Continue;
	}

	override Status enter(ir.Unittest u)
	{
		u._body.statements = manipNodes(u._body.statements, &removeConditionals);
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		s.members.nodes = manipNodes(s.members.nodes, &removeConditionals);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		c.members.nodes = manipNodes(c.members.nodes, &removeConditionals);
		return Continue;
	}

	override Status enter(ir.Attribute a)
	{
		a.members.nodes = manipNodes(a.members.nodes, &removeConditionals);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		i.members.nodes = manipNodes(i.members.nodes, &removeConditionals);
		return Continue;
	}
}
