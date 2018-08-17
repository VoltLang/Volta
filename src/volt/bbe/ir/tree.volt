/*!
 * The BBEIR representative data structures.
 *
 * These data structures should be mostly 'mechanism';
 * their representation, dumb construction, printing.  
 * For example, an `Instruction` can't take an
 * `Instruction` as an argument, despite the fact
 * that `Instruction`s are `Value`s -- there should
 * be no code in here for verifying that arguments
 * passed to the `Instruction` constructor; that's
 * the builder code's responsibility.
 */
module volt.bbe.ir.tree;

import watt = [watt.text.sink, watt.conv];

/*!
 * Parent data structure.  
 * Not useful on its own, but contains
 * facilities common to all BBEIR data types.
 */
class Node
{
public:
	fn toStringSink(sink: watt.Sink) { sink("Node");}    //!< Print the source representation of this IR node.
	@property fn isInstruction() bool { return false; }  //!< Is this node an `Instruction`?
}

class Type : Node
{
public:
	enum Kind
	{
		Integer32,
	}

public:
	kind: Kind;

public:
	this(kind: Kind)
	{
		this.kind = kind;
	}

public:
	override fn toStringSink(sink: watt.Sink)
	{
		final switch (kind) with (Kind) {
		case Integer32: sink("@i32"); break;
		}
	}
}

class Value : Node
{
}

class Reference : Value
{
public:
	enum Kind
	{
		Variable,
		Block,
		Function,
	}

protected:
	union Union
	{
		var:   Variable;
		block: Block;
		func:  Function;
	}

public:
	name: string;
	kind: Kind;

protected:
	u: Union;

public:
	this(name: string, var: Variable)
	{
		this.name    = name;
		this.kind    = Kind.Variable;
		this.u.var   = var;
	}

	this(name: string, block: Block)
	{
		this.name    = name;
		this.kind    = Kind.Block;
		this.u.block = block;
	}

	this(name: string, func: Function)
	{
		this.name    = name;
		this.kind    = Kind.Function;
		this.u.func  = func;
	}

public:
	@property fn var() Variable
	{
		assert(kind == Kind.Variable, "reference.var, but the reference is not a variable");
		return u.var;
	}

	@property fn block() Block
	{
		assert(kind == Kind.Block, "reference.block, but the reference is not a block");
		return u.block;
	}

	@property fn func() Function
	{
		assert(kind == Kind.Function, "reference.func, but the reference is not a function");
		return u.func;
	}

public:
	override fn toStringSink(sink: watt.Sink)
	{
		sink(name);
	}
}

/*!
 * A named location of a given type that contains a `Value`.
 *
 * BBEIR is SSA -- each `Variable` is assigned to exactly once;
 * no more, no less.
 */
class Variable : Value
{
public:
	name:    string;
	type:    Type;
	assign:  Value;

public:
	this(name: string, type: Type, assign: Value)
	{
		this.name   = name;
		this.type   = type;
		this.assign = assign;
	}

public:
	override fn toStringSink(sink: watt.Sink)
	{
		sink(name);
		sink(": ");
		type.toStringSink(sink);
		sink(" = ");
		assign.toStringSink(sink);
	}
}

/*!
 * A special type of `Variable` that occurs in function parameter lists.
 *
 * The assign is null.
 */
class FunctionParameter : Variable
{
public:
	this(name: string, type: Type)
	{
		super(name, type, null);
	}

public:
	override fn toStringSink(sink: watt.Sink)
	{
		sink(name);
		sink(": ");
		type.toStringSink(sink);
	}
}

class IntegerValue : Value
{
public:
	type: Type;
	val:  u64;

public:
	this(type: Type, val: u64)
	{
		this.type = type;
		this.val  = val;
	}

public:
	override fn toStringSink(sink: watt.Sink) { sink(watt.toString(val)); }
}

/*!
 * An instruction does a thing to zero or more arguments.
 *
 * The arguments can be any `Value`, except other `Instruction`s.
 */
class Instruction : Value
{
public:
	//! The kinds of instructions we have.
	enum Kind
	{
		Add,   //!< arg0 + arg1
		Sub,   //!< arg0 - arg1
		Call,  //!< arg0(arg1, arg2, argn)
		Ret    //!< return [arg0]
	}

public:
	kind: Kind;     //!< What kind of instruction is this?
	args: Value[];  //!< What arguments are given to this instruction?

public:
	this(kind: Kind, args: Value[])
	{
		this.kind = kind;
		this.args = args;
	}

public:
	override @property fn isInstruction() bool { return true; }

	override fn toStringSink(sink: watt.Sink)
	{
		final switch (kind) with (Kind) {
		case Add:  sink("@add");  break;
		case Sub:  sink("@sub");  break;
		case Call: sink("@call"); break;
		case Ret:  sink("@ret");  break;
		}

		if (args.length == 0) {
			return;
		}

		sink(" ");
		foreach (i, arg; args) {
			arg.toStringSink(sink);
			if (i < args.length - 1) {
				sink(" ");
			}
		}
	}
}

class Block : Value
{
public:
	name:    string;
	values:  Value[];

public:
	this(name: string, values: Value[])
	{
		this.name         = name;
		this.values = values;
	}

public:
	override fn toStringSink(sink: watt.Sink)
	{
		sink(name);
		sink(":\n");
		foreach (instruction; values) {
			sink("\t");
			instruction.toStringSink(sink);
			sink("\n");
		}
	}
}

class Function : Value
{
public:
	name:   string;
	args:   FunctionParameter[];
	ret:    Type;
	blocks: Block[];

public:
	this(name: string, args: FunctionParameter[], ret: Type, blocks: Block[])
	{
		this.name   = name;
		this.args   = args;
		this.ret    = ret;
		this.blocks = blocks;
	}

public:
	override fn toStringSink(sink: watt.Sink)
	{
		sink("@fn ");
		sink(name);
		sink("(");
		foreach (i, arg; args) {
			arg.toStringSink(sink);
			if (i < args.length - 1) {
				sink(", ");
			}
		}
		sink(") ");
		sink(" {\n");
		foreach (block; blocks) {
			block.toStringSink(sink);
		}
		sink("}\n");
	}
}
