// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.statement;

import volt.ir.base;
import volt.ir.declaration;
import volt.ir.expression;
import volt.ir.toplevel;
import volt.ir.context;


/**
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

/**
 * Base class for all statements.
 *
 * @ingroup irNode irStatement
 */
abstract class Statement : Node
{
public:
	this(NodeType nt) { super(nt); }
}

/**
 * A block statement is a group of zero or more statements.
 * Why these exist depends on where they live. 
 *
 * @ingroup irNode irStatement
 */
class BlockStatement : Statement
{
public:
	Node[] statements;
	/** The scope directly attached to a function has its parent
	 *  node set to that Function, otherwise it points to this
	 *  BlockStatement.
	 */
	Scope myScope;

public:
	this() { super(NodeType.BlockStatement); }
}

/**
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
}

/**
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
}

/**
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
}

/**
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
}

/**
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
}

/**
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
}

/**
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
}

/**
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
	Exp aggregate;
	Exp beginIntegerRange, endIntegerRange;  // aggregate will be null.
	BlockStatement block;

public:
	this() { super(NodeType.ForeachStatement); }
}

/**
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
	Statement[] childStatement;

public:
	this() { super(NodeType.LabelStatement); }
}

/**
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
}

/**
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
}

/**
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
}

/**
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
}

/**
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
}

/**
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
}

/**
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
}

/**
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
}

/**
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
}

/**
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
}

/**
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
	enum Kind
	{
		Exit,
		Success,
		Failure,
	}

public:
	Kind kind;
	BlockStatement block;

public:
	this() { super(NodeType.ScopeStatement); }
}

/**
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
}

/**
 * An EmptyStatement does nothing, successfully.
 *
 * @ingroup irNode irStatement
 */
class EmptyStatement : Statement
{
public:

public:
	this() { super(NodeType.EmptyStatement); }
}

/**
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
}

/**
 * The mixin statement mixes in a mixin function, mixin template
 * or a string.
 *
 * @ingroup irNode irStatement
 */
class MixinStatement : Statement
{
public:
	Exp stringExp; ///< Not optional for mixin("string").
	QualifiedName id; ///< Not optional for mixin .my.Ident!(...)

	BlockStatement resolved;

public:
	this() { super(NodeType.MixinStatement); }
}
