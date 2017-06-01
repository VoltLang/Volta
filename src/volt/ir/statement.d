// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.statement;

import volt.ir.base;
import volt.ir.declaration;
import volt.ir.expression;
import volt.ir.toplevel;
import volt.ir.context;


/*!
 * @defgroup irStatement IR Statement Nodes
 *
 * Statements make things happen.
 * They control the flow of execution, and can control lookup of
 * symbols in certain scopes. This is in contrast to expressions,
 * which compute values...and sometimes control flow. But the latter
 * is mostly the domain of statements, and allows Volt to be a 
 * turing complete language. Which is sometimes useful, we're told.
 *
 * @ingroup irNode
 */

/*!
 * Base class for all statements.
 *
 * @ingroup irNode irStatement
 */
abstract class Statement : Node
{
public:
	this(NodeType nt) { super(nt); }

	this(NodeType nt, Statement old)
	{
		super(nt, old);
	}
}

/*!
 * A block statement is a group of zero or more statements.
 * Why these exist depends on where they live. 
 *
 * @ingroup irNode irStatement
 */
class BlockStatement : Statement
{
public:
	Node[] statements;
	/*! The scope directly attached to a function has its parent
	 *  node set to that Function, otherwise it points to this
	 *  BlockStatement.
	 */
	Scope myScope;

public:
	this() { super(NodeType.BlockStatement); }

	this(BlockStatement old)
	{
		super(NodeType.BlockStatement, old);
		version (Volt) {
			this.statements = new old.statements[0 .. $];
		} else {
			this.statements = old.statements.dup;
		}
		this.myScope = old.myScope;
	}
}

/*!
 * The return statement returns execution to the caller
 * of the current function, and optionally returns a value.
 *
 * @ingroup irNode irStatement
 */
class ReturnStatement : Statement
{
public:
	Exp exp;  // Optional.

public:
	this() { super(NodeType.ReturnStatement); }

	this(ReturnStatement old)
	{
		super(NodeType.ReturnStatement, old);
		this.exp = old.exp;
	}
}

/*!
 * The asm statement contains inline assembly.
 * It's a list of tokens so different backends
 * can parse it however they want. It all still
 * has to lex as valid Volt, of course.
 *
 * @ingroup irNode irStatement
 */
class AsmStatement : Statement
{
public:
	Token[] tokens;

public:
	this() { super(NodeType.AsmStatement); }

	this(AsmStatement old)
	{
		super(NodeType.AsmStatement, old);
		version (Volt) {
			this.tokens = new old.tokens[0 .. $];
		} else {
			this.tokens = old.tokens;
		}
	}
}

/*!
 * The assert statement aborts if condition is flase, optionally
 * displaying message. isStatic determines whether condition is
 * checked at compile time or not.
 *
 * @ingroup irNode irStatement
 */
class AssertStatement : Statement
{
public:
	Exp condition;
	Exp message;
	bool isStatic;

public:
	this() { super(NodeType.AssertStatement); }

	this(AssertStatement old)
	{
		super(NodeType.AssertStatement, old);
		this.condition = old.condition;
		this.message = old.message;
		this.isStatic = old.isStatic;
	}
}

/*!
 * If exp is true, execution flows to thenState.
 * If exp is false, execution flows to elseState,
 * if it exists, otherwise it skips to the end of
 * the if statement.
 *
 * @ingroup irNode irStatement
 */
class IfStatement : Statement
{
public:
	Exp exp;
	BlockStatement thenState;
	BlockStatement elseState;  // Optional.
	string autoName;  // Optional. auto ____ = foo; if .length > 0.

public:
	this() { super(NodeType.IfStatement); }

	this(IfStatement old)
	{
		super(NodeType.IfStatement, old);
		this.exp = old.exp;
		this.thenState = old.thenState;
		this.elseState = old.elseState;
		this.autoName = old.autoName;
	}
}

/*!
 * The while statement keeps executing the statements
 * in block, as long as condition evaluates in true.
 *
 * @ingroup irNode irStatement
 */
class WhileStatement : Statement
{
public:
	Exp condition;
	BlockStatement block;

public:
	this() { super(NodeType.WhileStatement); }

	this(WhileStatement old)
	{
		super(NodeType.WhileStatement, old);
		this.condition = old.condition;
		this.block = old.block;
	}
}

/*!
 * Like a while statement, executes block while condition
 * is true. Unlike the while statement, at least one execution
 * of block is guaranteed.
 *
 * @ingroup irNode irStatement
 */
class DoStatement : Statement
{
public:
	BlockStatement block;
	Exp condition;

public:
	this() { super(NodeType.DoStatement); }

	this(DoStatement old)
	{
		super(NodeType.DoStatement, old);
		this.block = old.block;
		this.condition = old.condition;
	}
}

/*!
 * The for statement is a while statement that evaluates
 * init first (optionally introducing Variables into the
 * for's scope), and running increment at the end of each
 * block's execution. Other than that, it keeps executing
 * block while test evaluates to true.
 *
 * for (init; test; increment) block
 *
 * @ingroup irNode irStatement
 */
class ForStatement : Statement
{
public:
	Variable[] initVars; // Optional, exclusive with initExps
	Exp[] initExps; // Optional, exclusive with initVar
	Exp test;  // Optional.
	Exp[] increments;  // Optional.
	BlockStatement block;

public:
	this() { super(NodeType.ForStatement); }

	this(ForStatement old)
	{
		super(NodeType.ForStatement, old);
		this.initVars = old.initVars;
		this.initExps = old.initExps;
		this.test = old.test;
		this.increments = old.increments;
		this.block = old.block;
	}
}

/*!
 * The foreach statement loops over elements in an aggregate.
 * Arrays and AAs have builtin support, but users can define
 * iteration solutions for their own types too.
 *
 * @ingroup irNode irStatement
 */
class ForeachStatement : Statement
{
public:
	bool reverse;
	Variable[] itervars;
	bool[] refvars;
	Exp aggregate;
	Exp beginIntegerRange, endIntegerRange;  // aggregate will be null.
	BlockStatement block;
	Named opApplyType;

	//! If this is non null, the lowerer will decode strings with this.
	Function decodeFunction;

public:
	this() { super(NodeType.ForeachStatement); }

	this(ForeachStatement old)
	{
		super(NodeType.ForeachStatement, old);
		this.reverse = old.reverse;
		version (Volt) {
			this.itervars = new old.itervars[0 .. $];
			this.refvars = new old.refvars[0 .. $];
		} else {
			this.itervars = old.itervars.dup;
			this.refvars = old.refvars.dup;
		}
		this.aggregate = old.aggregate;
		this.beginIntegerRange = old.beginIntegerRange;
		this.endIntegerRange = old.endIntegerRange;
		this.block = old.block;
		this.opApplyType = old.opApplyType;

		this.decodeFunction = old.decodeFunction;
	}
}

/*!
 * A label statement associates a string with a position
 * in the statement stream. Goto can then be used to jump
 * to that position and anger Dijkstra. 
 *
 * @ingroup irNode irStatement
 */
class LabelStatement : Statement
{
public:
	string label;
	Node[] childStatement;

public:
	this() { super(NodeType.LabelStatement); }

	this(LabelStatement old)
	{
		super(NodeType.LabelStatement, old);
		this.label = old.label;
		version (Volt) {
			this.childStatement = new old.childStatement[0 .. $];
		} else {
			this.childStatement = old.childStatement.dup;
		}
	}
}

/*!
 * An ExpStatement wraps an Expression in a Statement.
 *
 * @ingroup irNode irStatement
 */
class ExpStatement : Statement
{
public:
	Exp exp;

public:
	this() { super(NodeType.ExpStatement); }

	this(ExpStatement old)
	{
		super(NodeType.ExpStatement, old);
		this.exp = old.exp;
	}
}

/*!
 * Represents a case in a switch statement.
 *
 * If firstExp !is null and secondExp is null:
 *     case firstExp:
 * If firstExp !is null and secondExp !is null:
 *     case firstExp: .. case secondExp:
 * If exps.length > 0:
 *     case exps[0], exps[1], ... exps[$-1]:
 * If isDefault:
 *     default:
 *
 * The above are all mutually exclusive.
 */
class SwitchCase : Node
{
public:
	Exp firstExp;
	Exp secondExp;
	Exp[] exps;
	bool isDefault;

	BlockStatement statements;

public:
	this() { super(NodeType.SwitchCase); }

	this(SwitchCase old)
	{
		super(NodeType.SwitchCase, old);
		this.firstExp = old.firstExp;
		this.secondExp = old.secondExp;
		version (Volt) {
			this.exps = new old.exps[0 .. $];
		} else {
			this.exps = old.exps.dup;
		}
		this.isDefault = old.isDefault;

		this.statements = old.statements;
	}
}

/*!
 * A switch statement jumps to various case labels depending
 * on the value of its condition.
 * 
 * Fallthrough is only permitted on empty cases, unlike C and C++.
 *
 * @ingroup irNode irStatement
 */
class SwitchStatement : Statement
{
public:
	bool isFinal;
	Exp condition;
	SwitchCase[] cases;
	Exp[] withs;


public:
	this() { super(NodeType.SwitchStatement); }

	this(SwitchStatement old)
	{
		super(NodeType.SwitchStatement, old);
		this.isFinal = old.isFinal;
		this.condition = old.condition;
		version (Volt) {
			this.cases = new old.cases[0 .. $];
			this.withs = new old.withs[0 .. $];
		} else {
			this.cases = old.cases.dup;
			this.withs = old.withs.dup;
		}
	}
}

/*!
 * The continue statement restarts a loop (while, dowhile, for, foreach).
 *
 * @ingroup irNode irStatement
 */
class ContinueStatement : Statement
{
public:
	string label;  // Optional.

public:
	this() { super(NodeType.ContinueStatement); }

	this(ContinueStatement old)
	{
		super(NodeType.ContinueStatement, old);
		this.label = old.label;
	}
}

/*!
 * The break statement halts execution of a loop or a switch statement.
 *
 * @ingroup irNode irStatement
 */
class BreakStatement : Statement
{
public:
	string label;  // Optional.

public:
	this() { super(NodeType.BreakStatement); }

	this(BreakStatement old)
	{
		super(NodeType.BreakStatement, old);
		this.label = old.label;
	}
}

/*!
 * The goto statement jumps to a label, or controls flow
 * inside a switch statement.
 *
 * @ingroup irNode irStatement
 */
class GotoStatement : Statement
{
public:
	string label;  // Optional.
	bool isDefault;
	bool isCase;
	Exp exp;  // Optional.

public:
	this() { super(NodeType.GotoStatement); }

	this(GotoStatement old)
	{
		super(NodeType.GotoStatement, old);
		this.label = old.label;
		this.isDefault = old.isDefault;
		this.isCase = old.isCase;
		this.exp = old.exp;
	}
}

/*!
 * All lookups inside of a WithStatement first check
 * exp before performing a regular lookup. Ambiguities
 * are still errors.
 *
 * @ingroup irNode irStatement
 */
class WithStatement : Statement
{
public:
	Exp exp;
	BlockStatement block;

public:
	this() { super(NodeType.WithStatement); }

	this(WithStatement old)
	{
		super(NodeType.WithStatement, old);
		this.exp = old.exp;
		this.block = old.block;
	}
}

/*!
 * A synchronized statement ensures that only one thread of
 * execution can enter its block. An explicit mutex may be provided.
 *
 * @ingroup irNode irStatement
 */
class SynchronizedStatement : Statement
{
public:
	Exp exp;  // Optional.
	BlockStatement block;

public:
	this() { super(NodeType.SynchronizedStatement); }

	this(SynchronizedStatement old)
	{
		super(NodeType.SynchronizedStatement, old);
		this.exp = old.exp;
		this.block = old.block;
	}
}

/*!
 * The try statement allows the resolution of throw statements,
 * by rerouting thrown exceptions into various catch blocks.
 *
 * @ingroup irNode irStatement
 */
class TryStatement : Statement
{
public:
	BlockStatement tryBlock;
	Variable[] catchVars;  // Optional.
	BlockStatement[] catchBlocks;  // Optional.
	BlockStatement catchAll;  // Optional.
	BlockStatement finallyBlock;  // Optional.

public:
	this() { super(NodeType.TryStatement); }

	this(TryStatement old)
	{
		super(NodeType.TryStatement, old);
		this.tryBlock = old.tryBlock;
		version (Volt) {
			this.catchVars = new old.catchVars[0 .. $];
			this.catchBlocks = new old.catchBlocks[0 .. $];
		} else {
			this.catchVars = old.catchVars.dup;
			this.catchBlocks = old.catchBlocks.dup;
		}
		this.catchAll = old.catchAll;
		this.finallyBlock = old.finallyBlock;
	}
}

/*!
 * A throw statements halts the current functions execution and
 * unwinds the stack until it hits a try statement with an appropriate
 * catch statement or, failing that, it halts execution of the entire
 * program.
 *
 * @ingroup irNode irStatement
 */
class ThrowStatement : Statement
{
public:
	Exp exp;

public:
	this() { super(NodeType.ThrowStatement); }

	this(ThrowStatement old)
	{
		super(NodeType.ThrowStatement, old);
		this.exp = old.exp;
	}
}

/*!
 * ScopeStatements are executed on various conditions. 
 * Exits are always executed when the given scope is left.
 * Successes are executed when the scope is left normally.
 * Failures are executed when the scope is left by way of an Exception.
 *
 * @ingroup irNode irStatement
 */
class ScopeStatement : Statement
{
public:
	ScopeKind kind;
	BlockStatement block;

public:
	this() { super(NodeType.ScopeStatement); }

	this(ScopeStatement old)
	{
		super(NodeType.ScopeStatement, old);
		this.kind = old.kind;
		this.block = old.block;
	}
}

/*!
 * Pragma statements do magical things.
 * pragma(lib, "SDL"), for instance, tells the compiler
 * to link with SDL without the user having to specify
 * it on the command line. What pragmas are supported vary
 * from compiler to compiler, the only thing specified is
 * that complying implementations must die on unknown pragmas
 * by default.
 *
 * @ingroup irNode irStatement
 */
class PragmaStatement : Statement
{
public:
	string type;
	Exp[] arguments;  // Optional.
	BlockStatement block;

public:
	this() { super(NodeType.PragmaStatement); }

	this(PragmaStatement old)
	{
		super(NodeType.PragmaStatement, old);
		this.type = old.type;
		version (Volt) {
			this.arguments = new old.arguments[0 .. $];
		} else {
			this.arguments = old.arguments.dup;
		}
		this.block = old.block;
	}
}

/*!
 * A ConditionStatement provides for conditional compilation
 * of statements. If condition is true, then it is as if block
 * was where the ConditionStatement was. Otherwise, the _else
 * block replaces it (if present). 
 *
 * @ingroup irNode irStatement
 */
class ConditionStatement : Statement
{
public:
	Condition condition;
	BlockStatement block;
	BlockStatement _else;  // Optional.

public:
	this() { super(NodeType.ConditionStatement); }

	this(ConditionStatement old)
	{
		super(NodeType.ConditionStatement, old);
		this.condition = old.condition;
		this.block = old.block;
		this._else = old._else;
	}
}

/*!
 * The mixin statement mixes in a mixin function, mixin template
 * or a string.
 *
 * @ingroup irNode irStatement
 */
class MixinStatement : Statement
{
public:
	Exp stringExp; //!< Not optional for mixin("string").
	QualifiedName id; //!< Not optional for mixin .my.Ident!(...)

	BlockStatement resolved;

public:
	this() { super(NodeType.MixinStatement); }

	this(MixinStatement old)
	{
		super(NodeType.MixinStatement, old);
		this.stringExp = old.stringExp;
		this.id = old.id;

		this.resolved = old.resolved;
	}
}
