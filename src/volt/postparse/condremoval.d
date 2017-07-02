// Copyright © 2012-2017, Bernard Helyer.
// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Code that removes volt version constructs.
 *
 * @ingroup passPost
 */
module volt.postparse.condremoval;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.visitor.manip;
import volt.visitor.visitor;


/*!
 * A pass that removes version and debug blocks, not static ifs.
 *
 * @ingroup passes passLang passPost
 */
class ConditionalRemoval : NullVisitor, Pass
{
public:
	VersionSet ver;


public:
	this(VersionSet ver)
	{
		this.ver = ver;
	}

	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close()
	{

	}


	/*
	 *
	 * Visitor functions.
	 *
	 */

	override Status enter(ir.Module m)
	{
		m.children.nodes = manipNodes(m.children.nodes);
		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		bs.statements = manipNodes(bs.statements);
		return Continue;
	}

	override Status enter(ir.Function func)
	{
		if (func.inContract !is null) {
			func.inContract.statements = manipNodes(func.inContract.statements);
		}
		if (func.outContract !is null) {
			func.outContract.statements = manipNodes(func.outContract.statements);
		}
		if (func._body !is null) {
			func._body.statements = manipNodes(func._body.statements);
		}
		return Continue;
	}

	override Status enter(ir.Unittest u)
	{
		u._body.statements = manipNodes(u._body.statements);
		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		if (s.members !is null) {
			s.members.nodes = manipNodes(s.members.nodes);
		}
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		if (c.members !is null) {
			c.members.nodes = manipNodes(c.members.nodes);
		}
		return Continue;
	}

	override Status enter(ir.Attribute a)
	{
		if (a.members !is null) {
			a.members.nodes = manipNodes(a.members.nodes);
		}
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		if (i.members !is null) {
			i.members.nodes = manipNodes(i.members.nodes);
		}
		return Continue;
	}

	override Status enter(ir.Condition c)
	{
		if (c.kind != ir.Condition.Kind.StaticIf) {
			return Continue;
		}
		throw panic(c, "should not find condition here.");
	}

	override Status visit(ir.TemplateDefinition td)
	{
		if (td._struct !is null) {
			return accept(td._struct, this);
		}
		if (td._union !is null) {
			return accept(td._union, this);
		}
		if (td._interface !is null) {
			return accept(td._interface, this);
		}
		if (td._class !is null) {
			return accept(td._class, this);
		}
		if (td._function !is null) {
			return accept(td._function, this);
		}
		throw panic("Invalid TemplateDefinition");
	}


protected:
	bool evaluateCondition(ir.Condition c)
	{
		if (c.kind == ir.Condition.Kind.Debug) {
			return ver.debugEnabled;
		}
		bool[] stack;
		evaluate(c, c.exp, stack);
		assert(stack.length == 1);
		return stack[0];
	}

	void evaluate(ir.Condition c, ir.Exp e, ref bool[] stack)
	{
		switch (e.nodeType) with (ir.NodeType) {
		case IdentifierExp:
			auto i = cast(ir.IdentifierExp) e;
			assert(i !is null);
			if (c.kind == ir.Condition.Kind.Version) {
				stack ~= ver.isVersionSet(i.value);
			} else if (c.kind == ir.Condition.Kind.Debug) {
				stack ~= ver.isDebugSet(i.value);
			} else {
				throw panic(c, "should not enter this path.");
			}		
			return;
		case Unary:
			auto u = cast(ir.Unary) e;
			assert(u !is null);
			if (u.op != ir.Unary.Op.Not) {
				goto default;
			}
			evaluate(c, u.value, stack);
			if (stack.length == 0) {
				goto default;
			}
			stack[$-1] = !stack[$-1];
			return;
		case BinOp:
			auto b = cast(ir.BinOp) e;
			assert(b !is null);
			evaluate(c, b.right, stack);
			evaluate(c, b.left, stack);
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
			throw makeExpected(e, "identifier, &&, ||, (), or !");
		}
	}

	/*!
	 * Replace conditionals with their children,
	 * or not, depending on their Condition.
	 */
	bool removeConditionals(ir.Node node, out ir.Node[] ret)
	{
		if (auto condstat = cast(ir.ConditionStatement) node) {

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

			if (ret.length > 0) {
				ret = manipNodes(ret);
			}

			return true;
		} else if (auto cond = cast(ir.ConditionTopLevel) node) {

			// We don't touch static ifs here.
			if (cond.condition.kind == ir.Condition.Kind.StaticIf) {
				return false;
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

			if (ret.length > 0) {
				ret = manipNodes(ret);
			}

			return true;
		} else if (auto unit = cast(ir.Unittest) node) {
			// @todo Handle unittest
			return true;
		} else {
			// Not a Condition at all.
			return false;
		}
		version (Volt) assert(false); // If
	}

	/*!
	 * @todo Remove when not compiling under D.
	 */
	ir.Node[] manipNodes(ir.Node[] nodes)
	{
		version (Volt) {
			return .manipNodes(nodes, removeConditionals);
		} else {
			return .manipNodes(nodes, &removeConditionals);
		}
	}
}
