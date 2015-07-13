// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.expression;
// Most of these can pass through to a lower function, see the IR.

version(Volt) {
	import watt.conv;
	import watt.text.utf;

	float toFloat(string) { return 0.0f; }
	double toDouble(string) { return 0.0; }
} else {
	import std.conv : to;
	import std.utf;

	private float toFloat(string s) { return to!float(s); }
	private double toDouble(string s) { return to!double(s); }
	private ulong toUlong(string s, int base = 10) { return to!ulong(s, base); }
	private int toInt(string s) { return to!int(s); }
}

import ir = volt.ir.ir;
import intir = volt.parser.intir;
import volt.ir.copy;
import volt.ir.util;

import volt.exceptions;
import volt.errors;
import volt.token.location;
import volt.token.stream;
import volt.parser.base;
import volt.parser.declaration;
import volt.util.string;


ir.Exp parseExp(TokenStream ts)
{
	auto assignExp = parseAssignExp(ts);
	return assignToExp(assignExp);
}

ir.Exp assignToExp(intir.AssignExp assign)
{
	if (assign.op == ir.BinOp.Op.None) {
		return ternaryToExp(assign.left);
	}
	assert(assign.right !is null);
	auto exp = new ir.BinOp();
	exp.location = assign.location;
	exp.op = assign.op;
	exp.left = ternaryToExp(assign.left);
	exp.right = assignToExp(assign.right);
	return exp;
}

ir.Exp ternaryToExp(intir.TernaryExp tern)
{
	ir.Exp exp;
	if (tern.ifTrue !is null) {
		auto newTern = new ir.Ternary();
		newTern.location = tern.location;
		newTern.condition = binexpToExp(tern.condition);
		newTern.ifTrue = ternaryToExp(tern.ifTrue);
		newTern.ifFalse = ternaryToExp(tern.ifFalse);
		exp = newTern;
	} else {
		exp = binexpToExp(tern.condition);
	}
	return exp;
}

class ExpOrOp
{
	intir.UnaryExp exp;
	ir.BinOp.Op op;
	ir.BinOp bin;

	this(intir.UnaryExp exp)
	{
		this.exp = exp;
	}

	this(ir.BinOp.Op op)
	{
		this.op = op;
	}

	@property bool isExp()
	{
		return exp !is null;
	}
}

ExpOrOp[] gatherExps(intir.BinExp bin)
{
	ExpOrOp[] list;
	while (bin.op != ir.BinOp.Op.None) {
		list ~= new ExpOrOp(bin.left);
		list ~= new ExpOrOp(bin.op);
		bin = bin.right;
	}
	list ~= new ExpOrOp(bin.left);
	return list;
}

ir.Exp binexpToExp(intir.BinExp bin)
{
	// Ladies and gentlemen, Mr. Edsger Dijkstra's shunting-yard algorithm! (polite applause)
	// Shouldn't be needed.

	ExpOrOp[] tokens = gatherExps(bin);
	ExpOrOp[] output;
	ir.BinOp.Op[] stack;

	// While there are tokens to be read.
	while (tokens.length > 0) {
		// Read a token.
		auto token = tokens[0];
		tokens = tokens[1 .. $];

		if (token.isExp) {
			// If the token is an expression, add it to the output queue.
			output ~= new ExpOrOp(token.exp);
		} else {
			// If the token is an operator
			auto op1 = token.op;
			// While there is an operator token on the top of the stack
			while (stack.length > 0) {
				// and op1 is left associative and its precedence is <= op2.
				if ((intir.isLeftAssociative(op1) && intir.getPrecedence(op1) <= intir.getPrecedence(stack[0])) || 
					(intir.getPrecedence(op1) < intir.getPrecedence(stack[0]))) {
				// or op1 has precedence < op2) {
					// pop op2 off the stack
					auto op2 = stack[0];
					stack = stack[1 .. $];
					// and onto the output queue.
					output ~= new ExpOrOp(op2); 
				} else {
					break;
				}
			}
			// Push op1 onto the stack.
			stack = op1 ~ stack;
		}
	}

	// When there are no more tokens to read:
	// While there are still operator tokens on the stack.
	while (stack.length > 0) {
		// Pop the operator onto the output queue.
		output ~= new ExpOrOp(stack[0]);
		stack = stack[1 .. $];
	}

	ir.Exp[] expstack;
	while (output.length > 0) {
		if (output[0].isExp) {
			expstack = unaryToExp(output[0].exp) ~ expstack;
		} else {
			assert(expstack.length >= 2);
			auto binout = new ir.BinOp();
			binout.location = expstack[0].location;
			binout.left = expstack[1];
			binout.right = expstack[0];
			binout.op = output[0].op;
			expstack = expstack[2 .. $];
			expstack = binout ~ expstack;
		}
		output = output[1 .. $];
	}
	assert(expstack.length == 1);
	return expstack[0];
}

ir.Exp unaryToExp(intir.UnaryExp unary)
{
	if (unary.op == ir.Unary.Op.None) {
		return postfixToExp(unary.location, unary.postExp);
	} else if (unary.op == ir.Unary.Op.Cast) {
		auto exp = new ir.Unary();
		exp.location = unary.castExp.location;
		exp.op = unary.op;
		exp.value = unaryToExp(unary.castExp.unaryExp);
		exp.type = unary.castExp.type;
		return exp;
	} else if (unary.op == ir.Unary.Op.New) {
		auto exp = new ir.Unary();
		exp.location = unary.newExp.location;
		exp.op = unary.op;
		exp.type = unary.newExp.type;
		exp.hasArgumentList = unary.newExp.hasArgumentList;
		foreach (arg; unary.newExp.argumentList) {
			exp.argumentList ~= assignToExp(arg);
		}
		return exp;
	} else if (unary.op == ir.Unary.Op.Dup) {
		auto exp = new ir.Unary();
		void transformDollar(ref ir.Exp rexp)
		{
			auto constant = cast(ir.Constant) rexp;
			if (constant is null || constant._string != "$") {
				return;
			}
			rexp = buildAccess(rexp.location, exp.dupName, "length");
		}
		exp.location = unary.dupExp.location;
		exp.op = unary.op;
		exp.dupName = unary.dupExp.name;
		exp.fullShorthand = unary.dupExp.shorthand;
		if (exp.dupName.identifiers.length == 1) {
			exp.value = buildIdentifierExp(exp.location, exp.dupName.identifiers[0].value);
		} else {
			auto qname = copy(exp.dupName);
			qname.identifiers = qname.identifiers[0 .. $-1];
			exp.value = buildAccess(exp.location, qname, exp.dupName.identifiers[$-1].value);
		}
		exp.dupBeginning = ternaryToExp(unary.dupExp.beginning);
		exp.dupEnd = ternaryToExp(unary.dupExp.end);
		transformDollar(exp.dupBeginning);
		transformDollar(exp.dupEnd);
		return exp;
	} else {
		auto exp = new ir.Unary();
		exp.location = unary.location;
		exp.op = unary.op;
		exp.value = unaryToExp(unary.unaryExp);
		return exp;
	}
	assert(false);
}

ir.Exp postfixToExp(Location location, intir.PostfixExp postfix, ir.Exp seed = null)
{
	if (seed is null) {
		seed = primaryToExp(postfix.primary);
	}
	if (postfix.op == ir.Postfix.Op.None) {
		return seed;
	} else {
		auto exp = new ir.Postfix();
		exp.location = location;
		exp.op = postfix.op;
		exp.child = seed;
		exp.argumentLabels = postfix.labels;
		if (exp.op == ir.Postfix.Op.Identifier) {
			assert(postfix.identifier !is null);
			exp.identifier = postfix.identifier;
		} else foreach (arg; postfix.arguments) {
			exp.arguments ~= assignToExp(arg);
			ir.Postfix.TagKind r;
			if (arg.taggedRef) {
				r = ir.Postfix.TagKind.Ref;
			} else if (arg.taggedOut) {
				r = ir.Postfix.TagKind.Out;
			} else {
				r = ir.Postfix.TagKind.None;
			}
			exp.argumentTags ~= r;
		}
		return postfixToExp(location, postfix.postfix, exp);
	}
	version(Volt) assert(false);
}

ir.Exp primaryToExp(intir.PrimaryExp primary)
{
	ir.Exp exp;
	switch (primary.op) {
	case intir.PrimaryExp.Type.Identifier:
	case intir.PrimaryExp.Type.DotIdentifier:
		auto i = new ir.IdentifierExp();
		i.globalLookup = primary.op == intir.PrimaryExp.Type.DotIdentifier;
		i.value = primary._string;
		exp = i;
		break;
	case intir.PrimaryExp.Type.This:
		auto i = new ir.IdentifierExp();
		i.value = "this";
		exp = i;
		break;
	case intir.PrimaryExp.Type.Super:
		auto i = new ir.IdentifierExp();
		i.value = "super";
		exp = i;
		break;
	case intir.PrimaryExp.Type.Null:
		auto c = new ir.Constant();
		c.u._pointer = null;
		c.type = new ir.NullType();
		c.isNull = true;
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.Dollar:
		auto c = new ir.Constant();
		c._string = "$";
		c.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Uint);
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.True:
		auto c = new ir.Constant();
		c.u._bool = true;
		c.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.False:
		auto c = new ir.Constant();
		c.u._bool = false;
		c.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.Typeid:
		auto ti = new ir.Typeid();
		if (primary._string !is null) {
			ti.ident = primary._string;
		} else if (primary.exp !is null) {
			ti.exp = primary.exp;
		} else {
			ti.type = primary.type;
		}
		exp = ti;
		break;
	case intir.PrimaryExp.Type.StringLiteral:
		auto c = new ir.Constant();
		c._string = primary._string;
		// c.type = immutable(char)[]
		c.type = buildArrayType(primary.location, buildStorageType(primary.location, ir.StorageType.Kind.Immutable, buildPrimitiveType(primary.location, ir.PrimitiveType.Kind.Char)));
		assert((c._string[$-1] == '"' || c._string[$-1] == '`') && c._string.length >= 2);
		c.arrayData = unescapeString(primary.location, c._string[1 .. $-1]);
		exp = c;
		break;
	case intir.PrimaryExp.Type.CharLiteral:
		auto c = new ir.Constant();
		c._string = primary._string;
		c.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Char);
		c.type.location = primary.location;
		assert(c._string[$-1] == '\'' && c._string.length >= 3);
		c.arrayData = unescapeString(primary.location, c._string[1 .. $-1]);
		if (c.arrayData.length > 1) {
			c.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Dchar);
			c.type.location = primary.location;
			auto str = cast(string) c.arrayData;
			version(Volt) {
				size_t index;
				c.u._ulong = decode(str, index);
			} else {
				size_t index;
				c.u._ulong = decodeFront(str, index);
			}
		}
		exp = c;
		break;
	case intir.PrimaryExp.Type.FloatLiteral:
		auto c = new ir.Constant();
		auto base = ir.PrimitiveType.Kind.Double;
		c._string = primary._string;
		while (c._string[$-1] == 'f' || c._string[$-1] == 'F' ||
			   c._string[$-1] == 'L') {
			if (c._string[$-1] == 'f' || c._string[$-1] == 'F') {
				base = ir.PrimitiveType.Kind.Float;
			} else if (c._string[$-1] == 'L') {
				base = ir.PrimitiveType.Kind.Double;
			}
			c._string = c._string[0 .. $-1];
		}
		if (base == ir.PrimitiveType.Kind.Float) {
			c.u._float = toFloat(c._string);
		} else {
			c.u._double = toDouble(c._string);
		}
		c.type = new ir.PrimitiveType(base);
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.IntegerLiteral:
		auto c = new ir.Constant();
		c._string = primary._string;
		auto base = ir.PrimitiveType.Kind.Int;
		bool explicitBase;

		// If there are any suffixes, change the type to match.
		while (c._string[$-1] == 'u' || c._string[$-1] == 'U' ||
			   c._string[$-1] == 'L') {
			if (c._string[$-1] == 'u' || c._string[$-1] == 'U') {
				explicitBase = true;
				if (base == ir.PrimitiveType.Kind.Long) {
					base = ir.PrimitiveType.Kind.Ulong;
				} else {
					base = ir.PrimitiveType.Kind.Uint;
				}
			} else if (c._string[$-1] == 'L') {
				explicitBase = true;
				if (base == ir.PrimitiveType.Kind.Uint) {
					base = ir.PrimitiveType.Kind.Ulong;
				} else {
					base = ir.PrimitiveType.Kind.Long;
				}
			}
			c._string = c._string[0 .. $-1];
		}

		if (c._string.length > 2 && (c._string[0 .. 2] == "0x" || c._string[0 .. 2] == "0b")) {
			auto prefix = c._string[0 .. 2];
			c._string = c._string[2 .. $];
			auto v = toUlong(c._string, prefix == "0x" ? 16 : 2);
			if (v > uint.max) {
				if (!explicitBase)
					base = ir.PrimitiveType.Kind.Long;
				c.u._long = cast(long)v;
			} else {
				if (!explicitBase)
					base = ir.PrimitiveType.Kind.Int;
				c.u._int = cast(int)v;
			}
		} else {
			// Checking should have been done in the lexer.
			auto v = toUlong(c._string);

			switch (base) with (ir.PrimitiveType.Kind) {
			case Int:
				if (v <= int.max) {
					c.u._int = cast(int)v;
				} else if (explicitBase) {
					c.u._long = cast(long)v;
				} else {
					throw makeInvalidIntegerLiteral(c.location);
				}
				break;
			case Uint:
				if (v <= uint.max) {
					c.u._uint = cast(uint)v;
				} else if (explicitBase) {
					c.u._ulong = v;
				} else {
					throw makeInvalidIntegerLiteral(c.location);
				}
				break;
			case Long:
				if (v <= long.max) {
					c.u._long = cast(long)v;
				} else {
					throw makeInvalidIntegerLiteral(c.location);
				}
				break;
			case Ulong:
				c.u._ulong = v;
				break;
			default:
				assert(false);
			}
		}
		c._string = "";
		c.type = new ir.PrimitiveType(base);
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.ParenExp:
		assert(primary.tlargs.length == 1);
		return assignToExp(primary.tlargs[0]);
	case intir.PrimaryExp.Type.ArrayLiteral:
		auto c = new ir.ArrayLiteral();
		foreach (arg; primary.arguments) {
			c.values ~= assignToExp(arg);
		}
		exp = c;
		break;
	case intir.PrimaryExp.Type.AssocArrayLiteral:
		auto c = new ir.AssocArray();
		for (size_t i = 0; i < primary.keys.length; ++i) {
			c.pairs ~= new ir.AAPair(assignToExp(primary.keys[i]), assignToExp(primary.arguments[i]));
			c.pairs[$-1].location = primary.keys[i].location;
		}
		exp = c;
		break;
	case intir.PrimaryExp.Type.Assert:
		auto c = new ir.Assert();
		c.condition = assignToExp(primary.arguments[0]);
		if (primary.arguments.length >= 2) {
			c.message = assignToExp(primary.arguments[1]);
		}
		exp = c;
		break;
	case intir.PrimaryExp.Type.Import:
		auto c = new ir.StringImport();
		c.filename = assignToExp(primary.arguments[0]);
		exp = c;
		break;
	case intir.PrimaryExp.Type.Is:
		return primary.isExp;
	case intir.PrimaryExp.Type.FunctionLiteral:
		return primary.functionLiteral;
	case intir.PrimaryExp.Type.StructLiteral:
		auto lit = new ir.StructLiteral();
		foreach (bexp; primary.arguments) {
			lit.exps ~= assignToExp(bexp);
		}
		exp = lit;
		break;
	case intir.PrimaryExp.Type.Traits:
		exp = primary.trait;
		break;
	case intir.PrimaryExp.Type.Type:
		auto te = new ir.TypeExp();
		te.type = primary.type;
		te.location = primary.location;
		auto pfix = new ir.Postfix();
		pfix.op = ir.Postfix.Op.Identifier;
		pfix.child = te;
		pfix.identifier = new ir.Identifier();
		pfix.identifier.location = primary.location;
		pfix.identifier.value = primary._string;
		exp = pfix;
		break;
	case intir.PrimaryExp.Type.TemplateInstance:
		exp = primary._template;
		break;
	case intir.PrimaryExp.Type.FunctionName:
		exp = new ir.TokenExp(ir.TokenExp.Type.Function);
		break;
	case intir.PrimaryExp.Type.PrettyFunctionName:
		exp = new ir.TokenExp(ir.TokenExp.Type.PrettyFunction);
		break;
	case intir.PrimaryExp.Type.File:
		exp = new ir.TokenExp(ir.TokenExp.Type.File);
		break;
	case intir.PrimaryExp.Type.Line:
		exp = new ir.TokenExp(ir.TokenExp.Type.Line);
		break;
	case intir.PrimaryExp.Type.VaArg:
		exp = primary.vaexp;
		break;
	default:
		throw panic(primary.location, "unhandled primary expression.");
	}

	exp.location = primary.location;
	return exp;
}

private intir.AssignExp[] _parseArgumentList(TokenStream ts, TokenType endChar = TokenType.CloseParen)
{
	intir.AssignExp[] pexps;
	while (ts.peek.type != endChar) {
		if (ts.peek.type == TokenType.End) {
			throw makeExpected(ts.peek.location, "end of argument list");
		}
		pexps ~= parseAssignExp(ts);
		if (ts.peek.type != endChar) {
			match(ts, TokenType.Comma);
		}
	}

	return pexps;
}

private intir.AssignExp[] _parseArgumentList(TokenStream ts, ref string[] labels, TokenType endChar = TokenType.CloseParen)
{
	intir.AssignExp[] pexps;
	while (ts.peek.type != endChar) {
		if (ts.peek.type == TokenType.End) {
			throw makeExpected(ts.peek.location, "end of argument list");
		}
		if (ts.peek.type == TokenType.Identifier && ts.lookahead(1).type == TokenType.Colon) {
			auto ident = match(ts, TokenType.Identifier);
			labels ~= ident.value;
			match(ts, TokenType.Colon);
		}
		pexps ~= parseAssignExp(ts);
		if (ts.peek.type != endChar) {
			match(ts, TokenType.Comma);
		}
	}

	if (labels.length != 0 && labels.length != pexps.length) {
		throw makeAllArgumentsMustBeLabelled(ts.peek.location);
	}

	return pexps;
}

// Parse an argument list from ts. Will end with ts.peek == endChar.
ir.Exp[] parseArgumentList(TokenStream ts, TokenType endChar = TokenType.CloseParen)
{
	intir.AssignExp[] pexps = _parseArgumentList(ts, endChar);

	ir.Exp[] outexps;
	foreach (exp; pexps) {
		outexps ~= assignToExp(exp);
	}
	assert(pexps.length == outexps.length);

	return outexps;
}

ir.IsExp parseIsExp(TokenStream ts)
{
	auto ie = new ir.IsExp();
	ie.location = ts.peek.location;

	match(ts, TokenType.Is);
	match(ts, TokenType.OpenParen);
	ie.type = parseType(ts);

	do switch (ts.peek.type) with (TokenType) {
		case CloseParen:
			break;
		case Identifier:
			if (ie.identifier.length > 0) {
				throw makeExpected(ts.peek.location, "is expression");
			}
			auto nameTok = match(ts, Identifier);
			ie.identifier = nameTok.value;
			break;
		case Colon:
			if (ie.compType != ir.IsExp.Comparison.None) {
				throw makeExpected(ts.peek.location, "is expression");
			}
			ts.get();
			ie.compType = ir.IsExp.Comparison.Implicit;
			break;
		case DoubleAssign:
			if (ie.compType != ir.IsExp.Comparison.None) {
				throw makeExpected(ts.peek.location, "is expression");
			}
			ts.get();
			ie.compType = ir.IsExp.Comparison.Exact;
			break;
		default:
			if (ie.compType == ir.IsExp.Comparison.None) {
				throw makeExpected(ts.peek.location, "'==' or ':'");
			}
			switch (ts.peek.type) with(TokenType) {
			case Struct, Union, Class, Enum, Interface, Function,
				 Delegate, Super, Const, Immutable, Inout, Shared,
				 Return:
				ie.specialisation = cast(ir.IsExp.Specialisation) ts.peek.type;
				ts.get();
				break;
			default:
				ie.specialisation = ir.IsExp.Specialisation.Type;
				ie.specType = parseType(ts);
				break;
			}
			break;
	} while (ts.peek.type != TokenType.CloseParen);
	match(ts, TokenType.CloseParen);

	return ie;
}

ir.FunctionLiteral parseFunctionLiteral(TokenStream ts)
{
	auto fn = new ir.FunctionLiteral();
	fn.location = ts.peek.location;

	switch (ts.peek.type) {
	case TokenType.Function:
		ts.get();
		fn.isDelegate = false;
		break;
	case TokenType.Delegate:
		ts.get();
		fn.isDelegate = true;
		break;
	case TokenType.Identifier:
		fn.isDelegate = true;
		auto nameTok = match(ts, TokenType.Identifier);
		fn.singleLambdaParam = nameTok.value;
		match(ts, TokenType.Assign);
		match(ts, TokenType.Greater);
		fn.lambdaExp = parseExp(ts);
		return fn;
	default:
		fn.isDelegate = true;
		break;
	}

	if (ts.peek.type != TokenType.OpenParen) {
		fn.returnType = parseType(ts);
	}

	match(ts, TokenType.OpenParen);
	while (ts.peek.type != TokenType.CloseParen) {
		auto param = new ir.FunctionParameter();
		param.location = ts.peek.location;
		param.type = parseType(ts);
		if (ts.peek.type == TokenType.Identifier) {
			auto nameTok = match(ts, TokenType.Identifier);
			param.name = nameTok.value;
		}
		fn.params ~= param;
		matchIf(ts, TokenType.Comma);
	}
	match(ts, TokenType.CloseParen);

	if (ts.peek.type == TokenType.Assign) {
		if (!fn.isDelegate || fn.returnType !is null) {
			throw makeExpected(ts.peek.location, "lambda expression.", true);
		}
		match(ts, TokenType.Assign);
		match(ts, TokenType.Greater);
		fn.lambdaExp = parseExp(ts);
		return fn;
	} else {
		fn.block = parseBlock(ts);
		return fn;
	}
	version(Volt) assert(false);
}

ir.TraitsExp parseTraitsExp(TokenStream ts)
{
	auto texp = new ir.TraitsExp();
	texp.location = ts.peek.location;

	match(ts, TokenType.__Traits);
	match(ts, TokenType.OpenParen);

	auto nameTok = match(ts, TokenType.Identifier);
	switch (nameTok.value) {
	case "getAttribute":
		texp.op = ir.TraitsExp.Op.GetAttribute;
		match(ts, TokenType.Comma);
		texp.target = parseQualifiedName(ts);
		match(ts, TokenType.Comma);
		texp.qname = parseQualifiedName(ts);
		break;
	default:
		throw makeExpected(nameTok.location, "__traits identifier");
	}

	match(ts, TokenType.CloseParen);
	return texp;
}

/*** ugly intir stuff ***/

intir.AssignExp parseAssignExp(TokenStream ts)
{
	auto exp = new intir.AssignExp();
	exp.taggedRef = matchIf(ts, TokenType.Ref);
	if (!exp.taggedRef) {
		exp.taggedOut = matchIf(ts, TokenType.Out);
	}
	auto origin = ts.peek.location;
	exp.left = parseTernaryExp(ts);
	switch (ts.peek.type) {
	case TokenType.Assign:
		exp.op = ir.BinOp.Op.Assign; break;
	case TokenType.PlusAssign:
		exp.op = ir.BinOp.Op.AddAssign; break;
	case TokenType.DashAssign:
		exp.op = ir.BinOp.Op.SubAssign; break;
	case TokenType.AsterixAssign:
		exp.op = ir.BinOp.Op.MulAssign; break;
	case TokenType.SlashAssign:
		exp.op = ir.BinOp.Op.DivAssign; break;
	case TokenType.PercentAssign:
		exp.op = ir.BinOp.Op.ModAssign; break;
	case TokenType.AmpersandAssign:
		exp.op = ir.BinOp.Op.AndAssign; break;
	case TokenType.PipeAssign:
		exp.op = ir.BinOp.Op.OrAssign; break;
	case TokenType.CaretAssign:
		exp.op = ir.BinOp.Op.XorAssign; break;
	case TokenType.TildeAssign:
		exp.op = ir.BinOp.Op.CatAssign; break;
	case TokenType.DoubleLessAssign:
		exp.op = ir.BinOp.Op.LSAssign; break;
	case TokenType.DoubleGreaterAssign:
		exp.op = ir.BinOp.Op.SRSAssign; break;
	case TokenType.TripleGreaterAssign:
		exp.op = ir.BinOp.Op.RSAssign; break;
	case TokenType.DoubleCaretAssign:
		exp.op = ir.BinOp.Op.PowAssign; break;
	default:
		exp.op = ir.BinOp.Op.None; break;
	}
	if (exp.op != ir.BinOp.Op.None) {
		ts.get();
		exp.right = parseAssignExp(ts);
	}
	exp.location = ts.peek.location - origin;
	return exp;
}

intir.TernaryExp parseTernaryExp(TokenStream ts)
{
	auto exp = new intir.TernaryExp();
	auto origin = ts.peek.location;
	exp.condition = parseBinExp(ts);
	if (ts.peek.type == TokenType.QuestionMark) {
		ts.get();
		exp.isTernary = true;
		exp.ifTrue = parseTernaryExp(ts);
		match(ts, TokenType.Colon);
		exp.ifFalse = parseTernaryExp(ts);
	}
	exp.location = ts.peek.location - origin;

	return exp;
}

intir.BinExp parseBinExp(TokenStream ts)
{
	auto exp = new intir.BinExp();
	exp.location = ts.peek.location;
	exp.left = parseUnaryExp(ts);

	switch (ts.peek.type) {
	case TokenType.Bang:
		if (ts.lookahead(1).type == TokenType.Is) {
			ts.get();
			exp.op = ir.BinOp.Op.NotIs;
		} else if (ts.lookahead(1).type == TokenType.In) {
			ts.get();
			exp.op = ir.BinOp.Op.NotIn;
		} else {
			goto default;
		}
		break;
	case TokenType.DoublePipe:
		exp.op = ir.BinOp.Op.OrOr; break;
	case TokenType.DoubleAmpersand:
		exp.op = ir.BinOp.Op.AndAnd; break;
	case TokenType.Pipe:
		exp.op = ir.BinOp.Op.Or; break;
	case TokenType.Caret:
		exp.op = ir.BinOp.Op.Xor; break;
	case TokenType.Ampersand:
		exp.op = ir.BinOp.Op.And; break;
	case TokenType.Is:
		exp.op = ir.BinOp.Op.Is; break;
	case TokenType.In:
		exp.op = ir.BinOp.Op.In; break;
	case TokenType.Less:
		exp.op = ir.BinOp.Op.Less; break;
	case TokenType.LessAssign:
		exp.op = ir.BinOp.Op.LessEqual; break;
	case TokenType.Greater:
		exp.op = ir.BinOp.Op.Greater; break;
	case TokenType.GreaterAssign:
		exp.op = ir.BinOp.Op.GreaterEqual; break;
	case TokenType.DoubleLess:
		exp.op = ir.BinOp.Op.LS; break;
	case TokenType.DoubleGreater:
		exp.op = ir.BinOp.Op.SRS; break;
	case TokenType.TripleGreater:
		exp.op = ir.BinOp.Op.RS; break;
	case TokenType.Plus:
		exp.op = ir.BinOp.Op.Add; break;
	case TokenType.Dash:
		exp.op = ir.BinOp.Op.Sub; break;
	case TokenType.Tilde:
		exp.op = ir.BinOp.Op.Cat; break;
	case TokenType.Slash:
		exp.op = ir.BinOp.Op.Div; break;
	case TokenType.Asterix:
		exp.op = ir.BinOp.Op.Mul; break;
	case TokenType.Percent:
		exp.op = ir.BinOp.Op.Mod; break;
	case TokenType.DoubleCaret:
		exp.op = ir.BinOp.Op.Pow; break;
	case TokenType.DoubleAssign:
		exp.op = ir.BinOp.Op.Equal; break;
	case TokenType.BangAssign:
		exp.op = ir.BinOp.Op.NotEqual; break;
	default:
		exp.op = ir.BinOp.Op.None; break;
	}
	if (exp.op != ir.BinOp.Op.None) {
		ts.get();
		exp.right = parseBinExp(ts);
	}

	exp.location.spanTo(ts.previous.location);
	return exp;
}

intir.UnaryExp parseUnaryExp(TokenStream ts)
{
	auto exp = new intir.UnaryExp();
	auto origin = ts.peek.location;
	switch (ts.peek.type) {
	case TokenType.Ampersand:
		match(ts, TokenType.Ampersand);
		exp.op = ir.Unary.Op.AddrOf;
		exp.unaryExp = parseUnaryExp(ts);
		break;
	case TokenType.DoublePlus:
		match(ts, TokenType.DoublePlus);
		exp.op = ir.Unary.Op.Increment;
		exp.unaryExp = parseUnaryExp(ts);
		break;
	case TokenType.DoubleDash:
		match(ts, TokenType.DoubleDash);
		exp.op = ir.Unary.Op.Decrement;
		exp.unaryExp = parseUnaryExp(ts);
		break;
	case TokenType.Asterix:
		match(ts, TokenType.Asterix);
		exp.op = ir.Unary.Op.Dereference;
		exp.unaryExp = parseUnaryExp(ts);
		break;
	case TokenType.Dash:
		match(ts, TokenType.Dash);
		exp.op = ir.Unary.Op.Minus;
		exp.unaryExp = parseUnaryExp(ts);
		break;
	case TokenType.Plus:
		match(ts, TokenType.Plus);
		exp.op = ir.Unary.Op.Plus;
		exp.unaryExp = parseUnaryExp(ts);
		break;
	case TokenType.Bang:
		match(ts, TokenType.Bang);
		exp.op = ir.Unary.Op.Not;
		exp.unaryExp = parseUnaryExp(ts);
		break;
	case TokenType.Tilde:
		match(ts, TokenType.Tilde);
		exp.op = ir.Unary.Op.Complement;
		exp.unaryExp = parseUnaryExp(ts);
		break;
	case TokenType.Cast:
		exp.op = ir.Unary.Op.Cast;
		exp.castExp = parseCastExp(ts);
		break;
	case TokenType.New:
		parseNewOrDup(ts, exp);
		break;
	default:
		exp.postExp = parsePostfixExp(ts);
		break;
	}
	exp.location = ts.peek.location - origin;

	return exp;
}

void parseNewOrDup(TokenStream ts, ref intir.UnaryExp exp)
{
	auto mark = ts.save();

	bool parseNew = true;
	match(ts, TokenType.New);
	int bracketDepth;
	while (ts.peek.type != TokenType.Semicolon && ts.peek.type != TokenType.End) {
		auto t = ts.get();
		if (t.type == TokenType.OpenBracket) {
			bracketDepth++;
			continue;
		} else if (t.type == TokenType.CloseBracket) {
			bracketDepth--;
			continue;
		}
		if (bracketDepth == 0) {
			if (t.type != TokenType.Dot && t.type != TokenType.Identifier) {
				parseNew = true;
				break;
			}
		} else if (bracketDepth == 1) {
			if (t.type == TokenType.DoubleDot) {
				parseNew = false;
				break;
			}
		}
	}
	ts.restore(mark);

	if (parseNew) {
		exp.op = ir.Unary.Op.New;
		exp.newExp = parseNewExp(ts);
	} else {
		exp.op = ir.Unary.Op.Dup;
		exp.dupExp = parseDupExp(ts);
	}
}

// Wrap a PrimaryExp in a TernaryExp.
private intir.TernaryExp toTernary(intir.PrimaryExp exp)
{
	auto t = new intir.TernaryExp();
	t.location = exp.location;
	t.condition = new intir.BinExp();
	t.condition.location = exp.location;
	t.condition.left = new intir.UnaryExp();
	t.condition.left.location = exp.location;
	t.condition.left.postExp = new intir.PostfixExp();
	t.condition.left.postExp.location = exp.location;
	t.condition.left.postExp.primary = exp;
	return t;
}

intir.DupExp parseDupExp(TokenStream ts)
{
	auto start = match(ts, TokenType.New);

	auto dupExp = new intir.DupExp();
	dupExp.name = parseQualifiedName(ts);
	match(ts, TokenType.OpenBracket);
	if (ts.peek.type == TokenType.DoubleDot) {
		// new foo[..];
		match(ts, TokenType.DoubleDot);
		auto beginning = new intir.PrimaryExp();
		beginning.location = ts.peek.location;
		beginning._string = "0";
		beginning.op = intir.PrimaryExp.Type.IntegerLiteral;
		auto end = new intir.PrimaryExp();
		end.location = ts.peek.location;
		end.op = intir.PrimaryExp.Type.Dollar;
		dupExp.beginning = toTernary(beginning);
		dupExp.end = toTernary(end);
		dupExp.shorthand = true;
	} else {
		// new foo[a..b];
		dupExp.beginning = parseTernaryExp(ts);
		match(ts, TokenType.DoubleDot);
		dupExp.end = parseTernaryExp(ts);
	}
	match(ts, TokenType.CloseBracket);

	return dupExp;
}

intir.NewExp parseNewExp(TokenStream ts)
{
	auto start = match(ts, TokenType.New);

	auto newExp = new intir.NewExp();
	newExp.type = parseType(ts);

	if (matchIf(ts, TokenType.OpenParen)) {
		newExp.hasArgumentList = true;
		newExp.argumentList = _parseArgumentList(ts);
		match(ts, TokenType.CloseParen);
	}

	newExp.location = ts.peek.location - start.location;
	return newExp;
}

intir.CastExp parseCastExp(TokenStream ts)
{
	// XXX: No idea if this is correct

	auto start = match(ts, TokenType.Cast);
	match(ts, TokenType.OpenParen);

	auto exp = new intir.CastExp();
	exp.type = parseType(ts);

	auto stop = match(ts, TokenType.CloseParen);
	exp.location = stop.location - start.location;

	exp.unaryExp = parseUnaryExp(ts);

	return exp;
}

intir.PostfixExp parsePostfixExp(TokenStream ts, int depth=0)
{
	depth++;
	auto exp = new intir.PostfixExp();
	auto origin = ts.peek.location;
	if (depth == 1) {
		exp.primary = parsePrimaryExp(ts);
	}

	switch (ts.peek.type) {
	case TokenType.Dot:
		ts.get();
		exp.identifier = parseIdentifier(ts);
		exp.op = ir.Postfix.Op.Identifier;
		exp.postfix = parsePostfixExp(ts, depth);
		break;
	case TokenType.DoublePlus:
		ts.get();
		exp.op = ir.Postfix.Op.Increment;
		exp.postfix = parsePostfixExp(ts, depth);
		break;
	case TokenType.DoubleDash:
		ts.get();
		exp.op = ir.Postfix.Op.Decrement;
		exp.postfix = parsePostfixExp(ts, depth);
		break;
	case TokenType.OpenParen:
		ts.get();
		exp.arguments = _parseArgumentList(ts, exp.labels);
		match(ts, TokenType.CloseParen);
		exp.op = ir.Postfix.Op.Call;
		exp.postfix = parsePostfixExp(ts, depth);
		break;
	case TokenType.OpenBracket:
		ts.get();
		if (ts.peek.type == TokenType.CloseBracket) {
			exp.op = ir.Postfix.Op.Slice;
		} else {
			exp.arguments ~= parseAssignExp(ts);
			if (ts.peek.type == TokenType.DoubleDot) {
				exp.op = ir.Postfix.Op.Slice;
				ts.get();
				exp.arguments ~= parseAssignExp(ts);
			} else {
				exp.op = ir.Postfix.Op.Index;
				if (ts.peek.type == TokenType.Comma) {
					ts.get();
				}
				exp.arguments ~= _parseArgumentList(ts, TokenType.CloseBracket);
			}
		}
		match(ts, TokenType.CloseBracket);
		exp.postfix = parsePostfixExp(ts, depth);
		break;
	default:
		break;
	}

	return exp;
}

intir.PrimaryExp parsePrimaryExp(TokenStream ts)
{
	auto exp = new intir.PrimaryExp();
	auto origin = ts.peek.location;
	switch (ts.peek.type) {
	case TokenType.Identifier:
		if (ts == [TokenType.Identifier, TokenType.Assign, TokenType.Greater]) {
			goto case TokenType.Delegate;
		}
		auto token = ts.get();
		if (ts.peek.type == TokenType.Bang && ts.lookahead(1).type != TokenType.Is) {
			ts.get();
			exp.op = intir.PrimaryExp.Type.TemplateInstance;
			exp._template = new ir.TemplateInstanceExp();
			exp._template.location = origin;
			exp._template.name = token.value;
			if (matchIf(ts, TokenType.OpenParen)) {
				while (ts.peek.type != ir.TokenType.CloseParen) {
					ir.TemplateInstanceExp.TypeOrExp tOrE;
					try {
						tOrE.type = parseType(ts);
					} catch (CompilerError) {
						tOrE.exp = parseExp(ts);
					}
					exp._template.types ~= tOrE;
					matchIf(ts, TokenType.Comma);
				}
				match(ts, TokenType.CloseParen);
			} else {
				ir.TemplateInstanceExp.TypeOrExp tOrE;
				try {
					tOrE.type = parseType(ts);
				} catch (CompilerError) {
					tOrE.exp = parseExp(ts);
				}
				exp._template.types ~= tOrE;
			}
			break;
		}
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.Identifier;
		break;
	case TokenType.Dot:
		ts.get();
		auto token = match(ts, TokenType.Identifier);
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.DotIdentifier;
		break;
	case TokenType.This:
		ts.get();
		exp.op = intir.PrimaryExp.Type.This;
		break;
	case TokenType.Super:
		ts.get();
		exp.op = intir.PrimaryExp.Type.Super;
		break;
	case TokenType.Null:
		ts.get();
		exp.op = intir.PrimaryExp.Type.Null;
		break;
	case TokenType.True:
		ts.get();
		exp.op = intir.PrimaryExp.Type.True;
		break;
	case TokenType.False:
		ts.get();
		exp.op = intir.PrimaryExp.Type.False;
		break;
	case TokenType.Dollar:
		ts.get();
		exp.op = intir.PrimaryExp.Type.Dollar;
		break;
	case TokenType.IntegerLiteral:
		auto token = ts.get();
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.IntegerLiteral;
		break;
	case TokenType.FloatLiteral:
		auto token = ts.get();
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.FloatLiteral;
		break;
	case TokenType.StringLiteral:
		auto token = ts.get();
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.StringLiteral;
		break;
	case TokenType.__File__:
		auto token = ts.get();
		exp.op = intir.PrimaryExp.Type.File;
		break;
	case TokenType.__Line__:
		auto token = ts.get();
		exp.op = intir.PrimaryExp.Type.Line;
		break;
	case TokenType.__Function__:
		auto token = ts.get();
		exp.op = intir.PrimaryExp.Type.FunctionName;
		break;
	case TokenType.__Pretty_Function__:
		auto token = ts.get();
		exp.op = intir.PrimaryExp.Type.PrettyFunctionName;
		break;
	case TokenType.CharacterLiteral:
		auto token = ts.get();
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.CharLiteral;
		break;
	case TokenType.Assert:
		ts.get();
		match(ts, TokenType.OpenParen);
		exp.arguments ~= parseAssignExp(ts);
		if (ts.peek.type == TokenType.Comma) {
			ts.get();
			exp.arguments ~= parseAssignExp(ts);
		}
		match(ts, TokenType.CloseParen);
		exp.op = intir.PrimaryExp.Type.Assert;
		break;
	case TokenType.Import:
		ts.get();
		match(ts, TokenType.OpenParen);
		exp.arguments ~= parseAssignExp(ts);
		match(ts, TokenType.CloseParen);
		exp.op = intir.PrimaryExp.Type.Import;
		break;
	case TokenType.OpenBracket:
		size_t i;
		bool isAA;
		while (ts.lookahead(i).type != TokenType.CloseBracket) {
			if (ts.lookahead(i).type == TokenType.Colon) {
				isAA = true;
			}
			i++;
			if (ts.lookahead(i).type == TokenType.Comma ||
				ts.lookahead(i).type == TokenType.End) {
				break;
			}
		}
		if (!isAA) {
			ts.get();
			exp.arguments = _parseArgumentList(ts, TokenType.CloseBracket);
			match(ts, TokenType.CloseBracket);
			exp.op = intir.PrimaryExp.Type.ArrayLiteral;
		} else {
			ts.get();
			while (ts.peek.type != TokenType.CloseBracket) {
				exp.keys ~= parseAssignExp(ts);
				match(ts, TokenType.Colon);
				exp.arguments ~= parseAssignExp(ts);
				if (ts.peek.type == TokenType.Comma) {
					ts.get();
				}
			}
			match(ts, TokenType.CloseBracket);
			assert(exp.keys.length == exp.arguments.length);
			exp.op = intir.PrimaryExp.Type.AssocArrayLiteral;
		}
		break;
	case TokenType.OpenParen:
		if (isFunctionLiteral(ts)) {
			goto case TokenType.Delegate;
		}
		match(ts, TokenType.OpenParen);
		if (isUnambiguouslyParenType(ts)) {
			exp.op = intir.PrimaryExp.Type.Type;
			exp.type = parseType(ts);
			match(ts, TokenType.CloseParen);
			match(ts, TokenType.Dot);
			if (matchIf(ts, TokenType.Typeid)) {
				exp.op = intir.PrimaryExp.Type.Typeid;
			} else {
				auto nameTok = match(ts, TokenType.Identifier);
				exp._string = nameTok.value;
			}
			break;
		}
		exp.tlargs ~= parseAssignExp(ts);
		match(ts, TokenType.CloseParen);
		exp.op = intir.PrimaryExp.Type.ParenExp;
		break;
	case TokenType.Bool, TokenType.Ubyte, TokenType.Byte,
		 TokenType.Short, TokenType.Ushort,
		 TokenType.Int, TokenType.Uint, TokenType.Long,
		 TokenType.Ulong, TokenType.Void, TokenType.Float,
		 TokenType.Double, TokenType.Real, TokenType.Char,
		 TokenType.Wchar, TokenType.Dchar:
		exp.op = intir.PrimaryExp.Type.Type;
		exp.type = parsePrimitiveType(ts);
		match(ts, TokenType.Dot);
		if (matchIf(ts, TokenType.Typeid)) {
			exp.op = intir.PrimaryExp.Type.Typeid;
		} else {
			auto nameTok = match(ts, TokenType.Identifier);
			exp._string = nameTok.value;
		}
		break;
	case TokenType.OpenBrace:
		ts.get();
		exp.op = intir.PrimaryExp.Type.StructLiteral;
		while (ts.peek.type != TokenType.CloseBrace) {
			exp.arguments ~= parseAssignExp(ts);
			matchIf(ts, TokenType.Comma);
		}
		match(ts, TokenType.CloseBrace);
		break;
	case TokenType.Typeid:
		ts.get();
		exp.op = intir.PrimaryExp.Type.Typeid;
		match(ts, TokenType.OpenParen);
		if (ts.peek.type == TokenType.Identifier) {
			auto nameTok = ts.get();
			exp._string = nameTok.value;
		}  else {
			auto mark = ts.save();
			try {
				exp.type = parseType(ts);
			} catch (CompilerError err) {
				if (err.neverIgnore) {
					throw err;
				}
				ts.restore(mark);
				exp.exp = parseExp(ts);
			}
		}
		match(ts, TokenType.CloseParen);
		break;
	case TokenType.Is:
		exp.op = intir.PrimaryExp.Type.Is;
		exp.isExp = parseIsExp(ts);
		break;
	case TokenType.Function, TokenType.Delegate:
		exp.op = intir.PrimaryExp.Type.FunctionLiteral;
		exp.functionLiteral = parseFunctionLiteral(ts);
		break;
	case TokenType.__Traits:
		exp.op = intir.PrimaryExp.Type.Traits;
		exp.trait = parseTraitsExp(ts);
		break;
	case TokenType.VaArg:
		exp.op = intir.PrimaryExp.Type.VaArg;
		exp.vaexp = parseVaArgExp(ts);
		break;
	default:
		auto mark = ts.save();
		try {
			exp.op = intir.PrimaryExp.Type.FunctionLiteral;
			exp.functionLiteral = parseFunctionLiteral(ts);
		} catch (CompilerError) {
			ts.restore(mark);
			throw makeExpected(ts.peek.location, "primary expression");
		}
		break;
	}

	exp.location = ts.peek.location - origin;

	if (ts == [TokenType.Dot, TokenType.Typeid] && exp.op != intir.PrimaryExp.Type.Typeid) {
		ts.get();
		ts.get();
		exp.exp = primaryToExp(exp);
		exp.op = intir.PrimaryExp.Type.Typeid;
		assert(exp.type is null);
	}
	
	return exp;
}

ir.VaArgExp parseVaArgExp(TokenStream ts)
{
	auto vaexp = new ir.VaArgExp();
	vaexp.location = ts.peek.location;
	match(ts, TokenType.VaArg);
	match(ts, TokenType.Bang);
	bool paren = matchIf(ts, TokenType.OpenParen);
	vaexp.type = parseType(ts);
	if (paren) {
		match(ts, TokenType.CloseParen);
	}
	match(ts, TokenType.OpenParen);
	vaexp.arg = parseExp(ts);
	match(ts, TokenType.CloseParen);
	return vaexp;
}

bool isUnambiguouslyParenType(TokenStream ts)
{
	switch (ts.peek.type) with (TokenType) {
	case Bool, Byte, Short, Int, Long,
		 Char, Ubyte, Ushort, Uint, Ulong,
		 Dchar, Wchar, Void:
		return true;
	default:
		return false;
	}
}

// Returns: true if the TokenStream is at a function literal.
bool isFunctionLiteral(TokenStream ts)
{
	if (ts.peek.type == TokenType.Function || ts.peek.type == TokenType.Delegate) {
		return true;
	}
	auto mark = ts.save();
	if (ts.peek.type != TokenType.OpenParen) {
		try {
			auto tmp = parseType(ts);
			return true;
		} catch (CompilerError e) {
			return false;
		}
		assert(false);
	}

	assert(ts.peek.type == TokenType.OpenParen);
	int parenDepth;
	while (!(parenDepth == 0 && ts.peek.type == TokenType.CloseParen)) {
		ts.get();
		if (ts.peek.type == TokenType.OpenParen) {
			parenDepth++;
		}
		if (ts.peek.type == TokenType.CloseParen && parenDepth > 0) {
			parenDepth--;
		}
	}
	match(ts, TokenType.CloseParen);

	if (ts.peek.type == TokenType.OpenBrace) {
		ts.restore(mark);
		return true;
	} else if (ts == [TokenType.Assign, TokenType.Greater]) {
		ts.restore(mark);
		return true;
	} else {
		ts.restore(mark);
		return false;
	}
	assert(false);
}
