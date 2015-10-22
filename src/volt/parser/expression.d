// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.expression;
// Most of these can pass through to a lower function, see the IR.

import watt.conv : toInt, toUlong, toFloat, toDouble;
import watt.text.utf : decode;

import ir = volt.ir.ir;
import intir = volt.parser.intir;
import volt.ir.copy;
import volt.ir.util;

import volt.exceptions;
import volt.errors;
import volt.token.location;
import volt.token.token : TokenType;
import volt.parser.base;
import volt.parser.declaration;
import volt.util.string;


ParseStatus parseExp(ParserStream ps, out ir.Exp exp)
{
	intir.AssignExp aexp;
	auto succeeded = parseAssignExp(ps, aexp);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.BinOp);
	}
	succeeded = assignToExp(ps, aexp, exp);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.BinOp);
	}
	return Succeeded;
}

ParseStatus assignToExp(ParserStream ps, intir.AssignExp assign, out ir.Exp exp)
{
	if (assign.op == ir.BinOp.Op.None) {
		ternaryToExp(ps, assign.left, exp);
		return Succeeded;
	}
	assert(assign.right !is null);
	auto bop = new ir.BinOp();
	bop.location = assign.location;
	bop.op = assign.op;
	auto succeeded = ternaryToExp(ps, assign.left, bop.left);
	if (!succeeded) {
		return parseFailed(ps, bop);
	}
	succeeded = assignToExp(ps, assign.right, bop.right);
	if (!succeeded) {
		return parseFailed(ps, bop);
	}
	exp = bop;
	return Succeeded;
}

ParseStatus ternaryToExp(ParserStream ps, intir.TernaryExp tern, out ir.Exp exp)
{
	if (tern.ifTrue !is null) {
		auto newTern = new ir.Ternary();
		newTern.location = tern.location;
		auto succeeded = binexpToExp(ps, tern.condition, newTern.condition);
		if (!succeeded) {
			return parseFailed(ps, newTern);
		}
		succeeded = ternaryToExp(ps, tern.ifTrue, newTern.ifTrue);
		if (!succeeded) {
			return parseFailed(ps, newTern);
		}
		succeeded = ternaryToExp(ps, tern.ifFalse, newTern.ifFalse);
		if (!succeeded) {
			return parseFailed(ps, newTern);
		}
		exp = newTern;
	} else {
		auto succeeded = binexpToExp(ps, tern.condition, exp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Ternary);
		}
	}
	return Succeeded;
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

ParseStatus binexpToExp(ParserStream ps, intir.BinExp bin, out ir.Exp exp)
{
	// Ladies and gentlemen, Mr. Edsger Dijkstra's shunting-yard algorithm! (polite applause)

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
			ir.Exp uexp;
			auto succeeded = unaryToExp(ps, output[0].exp, uexp);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.BinOp);
			}
			expstack = uexp ~ expstack;
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
	exp = expstack[0];
	return Succeeded;
}

ParseStatus unaryToExp(ParserStream ps, intir.UnaryExp unary, out ir.Exp exp)
{
	if (unary.op == ir.Unary.Op.None) {
		auto succeeded = postfixToExp(ps, unary.location, exp, unary.postExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
	} else if (unary.op == ir.Unary.Op.Cast) {
		auto u = new ir.Unary();
		u.location = unary.castExp.location;
		u.op = unary.op;
		auto succeeded = unaryToExp(ps, unary.castExp.unaryExp, u.value);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		u.type = unary.castExp.type;
		exp = u;
	} else if (unary.op == ir.Unary.Op.New) {
		auto u = new ir.Unary();
		u.location = unary.newExp.location;
		u.op = unary.op;
		u.type = unary.newExp.type;
		u.hasArgumentList = unary.newExp.hasArgumentList;
		foreach (arg; unary.newExp.argumentList) {
			ir.Exp e;
			auto succeeded = assignToExp(ps, arg, e);
			if (!succeeded) {
				return parseFailed(ps, u);
			}
			u.argumentList ~= e;
		}
		exp = u;
	} else if (unary.op == ir.Unary.Op.Dup) {
		auto u = new ir.Unary();
		void transformDollar(ref ir.Exp rexp)
		{
			auto constant = cast(ir.Constant) rexp;
			if (constant is null || constant._string != "$") {
				return;
			}
			rexp = buildAccess(rexp.location, u.dupName, "length");
		}
		u.location = unary.dupExp.location;
		u.op = unary.op;
		u.dupName = unary.dupExp.name;
		u.fullShorthand = unary.dupExp.shorthand;
		if (u.dupName.identifiers.length == 1) {
			u.value = buildIdentifierExp(u.location, u.dupName.identifiers[0].value);
		} else {
			auto qname = copy(u.dupName);
			qname.identifiers = qname.identifiers[0 .. $-1];
			u.value = buildAccess(u.location, qname, u.dupName.identifiers[$-1].value);
		}
		auto succeeded = ternaryToExp(ps, unary.dupExp.beginning, u.dupBeginning);
		if (!succeeded) {
			return parseFailed(ps, u);
		}
		succeeded = ternaryToExp(ps, unary.dupExp.end, u.dupEnd);
		if (!succeeded) {
			return parseFailed(ps, u);
		}
		transformDollar(u.dupBeginning);
		transformDollar(u.dupEnd);
		exp = u;
	} else {
		auto u = new ir.Unary();
		u.location = unary.location;
		u.op = unary.op;
		auto succeeded = unaryToExp(ps, unary.unaryExp, u.value);
		if (!succeeded) {
			return parseFailed(ps, u);
		}
		exp = u;
	}
	return Succeeded;
}

ParseStatus postfixToExp(ParserStream ps, Location location, out ir.Exp exp, intir.PostfixExp postfix, ir.Exp seed = null)
{
	if (seed is null) {
		auto succeeded = primaryToExp(ps, postfix.primary, seed);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
	}
	if (postfix.op == ir.Postfix.Op.None) {
		exp = seed;
	} else {
		auto p = new ir.Postfix();
		p.location = location;
		p.op = postfix.op;
		p.child = seed;
		p.argumentLabels = postfix.labels;
		if (p.op == ir.Postfix.Op.Identifier) {
			assert(postfix.identifier !is null);
			p.identifier = postfix.identifier;
		} else foreach (arg; postfix.arguments) {
			ir.Exp parg;
			auto succeeded = assignToExp(ps, arg, parg);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Postfix);
			}
			p.arguments ~= parg;
			ir.Postfix.TagKind r;
			if (arg.taggedRef) {
				r = ir.Postfix.TagKind.Ref;
			} else if (arg.taggedOut) {
				r = ir.Postfix.TagKind.Out;
			} else {
				r = ir.Postfix.TagKind.None;
			}
			p.argumentTags ~= r;
		}
		ir.Exp theExp;
		auto succeeded = postfixToExp(ps, location, theExp, postfix.postfix, p);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
		exp = theExp;
	}
	return Succeeded;
}

ParseStatus primaryToExp(ParserStream ps, intir.PrimaryExp primary, out ir.Exp exp)
{
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
		auto atype = buildArrayType(primary.location, buildPrimitiveType(primary.location, ir.PrimitiveType.Kind.Char));
		atype.base.isImmutable = true;
		c.type = atype;
		assert((c._string[$-1] == '"' || c._string[$-1] == '`') && c._string.length >= 2);
		if (c._string[0] == '`' || c._string[0] == 'r') {
			int start = c._string[0] == '`' ? 1 : 2;
			c.arrayData = cast(immutable(void)[]) c._string[cast(size_t)start .. $-1];
		} else {
			c.arrayData = unescapeString(primary.location, c._string[1 .. $-1]);
		}
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
			size_t index;
			c.u._ulong = decode(str, index);
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
		while (c._string[$-1] == 'u' ||
		       c._string[$-1] == 'U' ||
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
				} else if (!explicitBase) {
					c.u._long = cast(long)v;
				} else {
					return invalidIntegerLiteral(ps, c.location);
				}
				break;
			case Uint:
				if (v <= uint.max) {
					c.u._uint = cast(uint)v;
				} else if (!explicitBase) {
					c.u._ulong = v;
				} else {
					return invalidIntegerLiteral(ps, c.location);
				}
				break;
			case Long:
				if (v <= long.max) {
					c.u._long = cast(long)v;
				} else {
					return invalidIntegerLiteral(ps, c.location);
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
		auto succeeded = assignToExp(ps, primary.tlargs[0], exp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Invalid);
		}
		break;
	case intir.PrimaryExp.Type.ArrayLiteral:
		auto c = new ir.ArrayLiteral();
		foreach (arg; primary.arguments) {
			ir.Exp e;
			auto succeeded = assignToExp(ps, arg, e);
			if (!succeeded) {
				return parseFailed(ps, c);
			}
			c.values ~= e;
		}
		exp = c;
		break;
	case intir.PrimaryExp.Type.AssocArrayLiteral:
		auto c = new ir.AssocArray();
		for (size_t i = 0; i < primary.keys.length; ++i) {
			ir.Exp k, v;
			auto succeeded = assignToExp(ps, primary.keys[i], k);
			if (!succeeded) {
				return parseFailed(ps, c);
			}
			succeeded = assignToExp(ps, primary.arguments[i], v);
			if (!succeeded) {
				return parseFailed(ps, c);
			}
			c.pairs ~= new ir.AAPair(k, v);
			c.pairs[$-1].location = primary.keys[i].location;
		}
		exp = c;
		break;
	case intir.PrimaryExp.Type.Assert:
		auto c = new ir.Assert();
		auto succeeded = assignToExp(ps, primary.arguments[0], c.condition);
		if (!succeeded) {
			return parseFailed(ps, c);
		}
		if (primary.arguments.length >= 2) {
			succeeded = assignToExp(ps, primary.arguments[1], c.message);
			if (!succeeded) {
				return parseFailed(ps, c);
			}
		}
		exp = c;
		break;
	case intir.PrimaryExp.Type.Import:
		auto c = new ir.StringImport();
		auto succeeded = assignToExp(ps, primary.arguments[0], c.filename);
		if (!succeeded) {
			return parseFailed(ps, c);
		}
		exp = c;
		break;
	case intir.PrimaryExp.Type.Is:
		exp = primary.isExp;
		return Succeeded;
	case intir.PrimaryExp.Type.FunctionLiteral:
		exp = primary.functionLiteral;
		return Succeeded;
	case intir.PrimaryExp.Type.StructLiteral:
		auto lit = new ir.StructLiteral();
		foreach (bexp; primary.arguments) {
			ir.Exp e;
			auto succeeded = assignToExp(ps, bexp, e);
			if (!succeeded) {
				return parseFailed(ps, lit);
			}
			lit.exps ~= e;
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
		return parsePanic(ps, primary.location, ir.NodeType.Invalid, "unhandled primary expression.");
	}

	exp.location = primary.location;
	return Succeeded;
}

private ParseStatus _parseArgumentList(ParserStream ps, out intir.AssignExp[] pexps, TokenType endChar = TokenType.CloseParen)
{
	while (ps.peek.type != endChar) {
		if (ps.peek.type == TokenType.End) {
			return parseExpected(ps, ps.peek.location, ir.NodeType.Postfix, "end of argument list");
		}
		intir.AssignExp e;
		auto succeeded = parseAssignExp(ps, e);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
		pexps ~= e;
		if (ps.peek.type != endChar) {
			succeeded = match(ps, ir.NodeType.Postfix, TokenType.Comma);
			if (!succeeded) {
				return succeeded;
			}
		}
	}

	return Succeeded;
}

private ParseStatus _parseArgumentList(ParserStream ps, out intir.AssignExp[] pexps, ref string[] labels, TokenType endChar = TokenType.CloseParen)
{
	while (ps.peek.type != endChar) {
		if (ps.peek.type == TokenType.End) {
			return unexpectedToken(ps, ir.NodeType.Postfix);
		}
		if (ps.peek.type == TokenType.Identifier && ps.lookahead(1).type == TokenType.Colon) {
			auto ident = ps.get();
			labels ~= ident.value;
			if (ps != TokenType.Colon) {
				return unexpectedToken(ps, ir.NodeType.Postfix);
			}
			ps.get();
		}
		intir.AssignExp e;
		auto succeeded = parseAssignExp(ps, e);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
		pexps ~= e;
		if (ps.peek.type != endChar) {
			if (ps != TokenType.Comma) {
				return unexpectedToken(ps, ir.NodeType.Postfix);
			}
			ps.get();
		}
	}

	if (labels.length != 0 && labels.length != pexps.length) {
		// TODO the location should be better
		return allArgumentsMustBeLabelled(ps, ps.peek.location);
	}

	return Succeeded;
}

// Parse an argument list from ps. Will end with ps.peek == endChar.
ParseStatus parseArgumentList(ParserStream ps, out ir.Exp[] outexps, TokenType endChar = TokenType.CloseParen)
{
	intir.AssignExp[] pexps;
	auto succeeded = _parseArgumentList(ps, pexps, endChar);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Postfix);
	}

	foreach (exp; pexps) {
		ir.Exp e;
		succeeded = assignToExp(ps, exp, e);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
		outexps ~= e;
	}
	assert(pexps.length == outexps.length);

	return Succeeded;
}

ParseStatus parseIsExp(ParserStream ps, out ir.IsExp ie)
{
	ie = new ir.IsExp();
	ie.location = ps.peek.location;

	auto succeeded = match(ps, ir.NodeType.IsExp, [TokenType.Is, TokenType.OpenParen]);
	if (!succeeded) {
		return succeeded;
	}
	succeeded = parseType(ps, ie.type);
	if (!succeeded) {
		return parseFailed(ps, ie);
	}

	do switch (ps.peek.type) with (TokenType) {
		case CloseParen:
			break;
		case Identifier:
			if (ie.identifier.length > 0) {
				return parseExpected(ps, ps.peek.location, ir.NodeType.Identifier, "is expression");
			}
			auto nameTok = ps.get();
			ie.identifier = nameTok.value;
			break;
		case Colon:
			if (ie.compType != ir.IsExp.Comparison.None) {
				return parseExpected(ps, ps.peek.location, ir.NodeType.Identifier, "is expression");
			}
			ps.get();
			ie.compType = ir.IsExp.Comparison.Implicit;
			break;
		case DoubleAssign:
			if (ie.compType != ir.IsExp.Comparison.None) {
				return parseExpected(ps, ps.peek.location, ir.NodeType.Identifier, "is expression");
			}
			ps.get();
			ie.compType = ir.IsExp.Comparison.Exact;
			break;
		default:
			if (ie.compType == ir.IsExp.Comparison.None) {
				return parseExpected(ps, ps.peek.location, ir.NodeType.Identifier, "'==' or ':'");
			}
			switch (ps.peek.type) {
			case Struct, Union, Class, Enum, Interface, Function,
				 Delegate, Super, Const, Immutable, Inout, Shared,
				 Return:
				ie.specialisation = cast(ir.IsExp.Specialisation) ps.peek.type;
				ps.get();
				break;
			default:
				ie.specialisation = ir.IsExp.Specialisation.Type;
				succeeded = parseType(ps, ie.specType);
				if (!succeeded) {
					return parseFailed(ps, ie);
				}
				break;
			}
			break;
	} while (ps.peek.type != TokenType.CloseParen);
	return match(ps, ie, TokenType.CloseParen);
}

ParseStatus parseFunctionLiteral(ParserStream ps, out ir.FunctionLiteral fn)
{
	fn = new ir.FunctionLiteral();
	fn.location = ps.peek.location;

	switch (ps.peek.type) {
	case TokenType.Function:
		ps.get();
		fn.isDelegate = false;
		break;
	case TokenType.Delegate:
		ps.get();
		fn.isDelegate = true;
		break;
	case TokenType.Identifier:
		fn.isDelegate = true;
		auto nameTok = ps.get();
		fn.singleLambdaParam = nameTok.value;
		auto succeeded = match(ps, ir.NodeType.Function, [TokenType.Assign, TokenType.Greater]);
		if (!succeeded) {
			return succeeded;
		}
		succeeded = parseExp(ps, fn.lambdaExp);
		if (!succeeded) {
			return parseFailed(ps, fn);
		}
		return Succeeded;
	default:
		fn.isDelegate = true;
		break;
	}

	if (ps.peek.type != TokenType.OpenParen) {
		auto succeeded = parseType(ps, fn.returnType);
		if (!succeeded) {
			return parseFailed(ps, fn);
		}
	}

	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, fn);
	}
	ps.get();
	while (ps.peek.type != TokenType.CloseParen) {
		auto param = new ir.FunctionParameter();
		param.location = ps.peek.location;
		auto succeeded = parseType(ps, param.type);
		if (!succeeded) {
			return parseFailed(ps, fn);
		}
		if (ps.peek.type == TokenType.Identifier) {
			auto nameTok = ps.get();
			param.name = nameTok.value;
		}
		fn.params ~= param;
		if (ps != TokenType.Comma) {
			return unexpectedToken(ps, fn);
		}
		ps.get();
	}
	ps.get();  // CloseParen

	if (ps.peek.type == TokenType.Assign) {
		if (!fn.isDelegate || fn.returnType !is null) {
			parseExpected(ps, ps.peek.location, fn, "lambda expression");
			ps.neverIgnoreError = true;
			return Failed;
		}
		auto succeeded = match(ps, ir.NodeType.Function, [TokenType.Assign, TokenType.Greater]);
		if (!succeeded) {
			return succeeded;
		}
		succeeded = parseExp(ps, fn.lambdaExp);
		if (!succeeded) {
			return parseFailed(ps, fn);
		}
		return Succeeded;
	} else {
		auto succeeded = parseBlock(ps, fn.block);
		if (!succeeded) {
			return parseFailed(ps, fn);
		}
		return Succeeded;
	}
	version (Volt) assert(false); // If
}

ParseStatus parseTraitsExp(ParserStream ps, out ir.TraitsExp texp)
{
	texp = new ir.TraitsExp();
	texp.location = ps.peek.location;

	auto succeeded = checkTokens(ps, ir.NodeType.TraitsExp,
		[TokenType.__Traits, TokenType.OpenParen, TokenType.Identifier]);
	if (!succeeded) {
		return succeeded;
	}
	ps.get();
	ps.get();

	auto nameTok = ps.get();
	switch (nameTok.value) {
	case "getAttribute":
		texp.op = ir.TraitsExp.Op.GetAttribute;
		succeeded = match(ps, texp, TokenType.Comma);
		if (!succeeded) {
			return succeeded;
		}
		succeeded = parseQualifiedName(ps, texp.target);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TraitsExp);
		}
		succeeded = match(ps, texp, TokenType.Comma);
		if (!succeeded) {
			return succeeded;
		}
		succeeded = parseQualifiedName(ps, texp.qname);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TraitsExp);
		}
		break;
	default:
		return parseExpected(ps, nameTok.location, texp, "__traits identifier");
	}

	return match(ps, texp, TokenType.CloseParen);
}

/*** ugly intir stuff ***/

ParseStatus parseAssignExp(ParserStream ps, out intir.AssignExp exp)
{
	exp = new intir.AssignExp();
	exp.taggedRef = matchIf(ps, TokenType.Ref);
	if (!exp.taggedRef) {
		exp.taggedOut = matchIf(ps, TokenType.Out);
	}
	auto origin = ps.peek.location;
	auto succeeded = parseTernaryExp(ps, exp.left);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.BinOp);
	}
	switch (ps.peek.type) {
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
		ps.get();
		succeeded = parseAssignExp(ps, exp.right);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.BinOp);
		}
	}
	exp.location = ps.peek.location - origin;
	return Succeeded;
}

ParseStatus parseTernaryExp(ParserStream ps, out intir.TernaryExp exp)
{
	exp = new intir.TernaryExp();
	auto origin = ps.peek.location;
	auto succeeded = parseBinExp(ps, exp.condition);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Ternary);
	}
	if (ps.peek.type == TokenType.QuestionMark) {
		ps.get();
		exp.isTernary = true;
		succeeded = parseTernaryExp(ps, exp.ifTrue);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Ternary);
		}
		if (ps != TokenType.Colon) {
			return unexpectedToken(ps, ir.NodeType.Ternary);
		}
		ps.get();
		succeeded = parseTernaryExp(ps, exp.ifFalse);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Ternary);
		}
	}
	exp.location = ps.peek.location - origin;

	return Succeeded;
}

ParseStatus parseBinExp(ParserStream ps, out intir.BinExp exp)
{
	exp = new intir.BinExp();
	exp.location = ps.peek.location;
	auto succeeded = parseUnaryExp(ps, exp.left);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.BinOp);
	}

	switch (ps.peek.type) {
	case TokenType.Bang:
		if (ps.lookahead(1).type == TokenType.Is) {
			ps.get();
			exp.op = ir.BinOp.Op.NotIs;
		} else if (ps.lookahead(1).type == TokenType.In) {
			ps.get();
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
		ps.get();
		succeeded = parseBinExp(ps, exp.right);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.BinOp);
		}
	}

	exp.location.spanTo(ps.previous.location);
	return Succeeded;
}

ParseStatus parseUnaryExp(ParserStream ps, out intir.UnaryExp exp)
{
	exp = new intir.UnaryExp();
	auto origin = ps.peek.location;
	switch (ps.peek.type) {
	case TokenType.Ampersand:
		ps.get();
		exp.op = ir.Unary.Op.AddrOf;
		auto succeeded = parseUnaryExp(ps, exp.unaryExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		break;
	case TokenType.DoublePlus:
		ps.get();
		exp.op = ir.Unary.Op.Increment;
		auto succeeded = parseUnaryExp(ps, exp.unaryExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		break;
	case TokenType.DoubleDash:
		ps.get();
		exp.op = ir.Unary.Op.Decrement;
		auto succeeded = parseUnaryExp(ps, exp.unaryExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		break;
	case TokenType.Asterix:
		ps.get();
		exp.op = ir.Unary.Op.Dereference;
		auto succeeded = parseUnaryExp(ps, exp.unaryExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		break;
	case TokenType.Dash:
		ps.get();
		exp.op = ir.Unary.Op.Minus;
		auto succeeded = parseUnaryExp(ps, exp.unaryExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		break;
	case TokenType.Plus:
		ps.get();
		exp.op = ir.Unary.Op.Plus;
		auto succeeded = parseUnaryExp(ps, exp.unaryExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		break;
	case TokenType.Bang:
		ps.get();
		exp.op = ir.Unary.Op.Not;
		auto succeeded = parseUnaryExp(ps, exp.unaryExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		break;
	case TokenType.Tilde:
		ps.get();
		exp.op = ir.Unary.Op.Complement;
		auto succeeded = parseUnaryExp(ps, exp.unaryExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		break;
	case TokenType.Cast:
		exp.op = ir.Unary.Op.Cast;
		auto succeeded = parseCastExp(ps, exp.castExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		break;
	case TokenType.New:
		auto succeeded = parseNewOrDup(ps, exp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		break;
	default:
		auto succeeded = parsePostfixExp(ps, exp.postExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
	}
	exp.location = ps.peek.location - origin;

	return Succeeded;
}

ParseStatus parseNewOrDup(ParserStream ps, ref intir.UnaryExp exp)
{
	auto mark = ps.save();

	bool parseNew = true;
	auto succeeded = match(ps, ir.NodeType.Unary, TokenType.New);
	if (!succeeded) {
		return succeeded;
	}
	int bracketDepth;
	while (ps.peek.type != TokenType.Semicolon && ps.peek.type != TokenType.End) {
		auto t = ps.get();
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
	ps.restore(mark);

	if (parseNew) {
		exp.op = ir.Unary.Op.New;
		succeeded = parseNewExp(ps, exp.newExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
	} else {
		exp.op = ir.Unary.Op.Dup;
		succeeded = parseDupExp(ps, exp.dupExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
	}

	return Succeeded;
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

ParseStatus parseDupExp(ParserStream ps, out intir.DupExp dupExp)
{
	auto succeeded = checkToken(ps, ir.NodeType.Unary, TokenType.New);
	if (!succeeded) {
		return succeeded;
	}
	auto start = ps.get();

	dupExp = new intir.DupExp();
	succeeded = parseQualifiedName(ps, dupExp.name);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Postfix);
	}
	succeeded = match(ps, ir.NodeType.Postfix, TokenType.OpenBracket);
	if (!succeeded) {
		return succeeded;
	}
	if (ps.peek.type == TokenType.DoubleDot) {
		// new foo[..];
		ps.get();  // Eat ..
		auto beginning = new intir.PrimaryExp();
		beginning.location = ps.peek.location;
		beginning._string = "0";
		beginning.op = intir.PrimaryExp.Type.IntegerLiteral;
		auto end = new intir.PrimaryExp();
		end.location = ps.peek.location;
		end.op = intir.PrimaryExp.Type.Dollar;
		dupExp.beginning = toTernary(beginning);
		dupExp.end = toTernary(end);
		dupExp.shorthand = true;
	} else {
		// new foo[a..b];
		succeeded = parseTernaryExp(ps, dupExp.beginning);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		succeeded = match(ps, ir.NodeType.Unary, TokenType.DoubleDot);
		if (!succeeded) {
			return succeeded;
		}
		succeeded = parseTernaryExp(ps, dupExp.end);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
	}
	return match(ps, ir.NodeType.Unary, TokenType.CloseBracket);
}

ParseStatus parseNewExp(ParserStream ps, out intir.NewExp newExp)
{
	Token start;
	auto succeeded = match(ps, ir.NodeType.Unary, TokenType.New, start);
	if (!succeeded) {
		return succeeded;
	}

	newExp = new intir.NewExp();
	if (ps.peek.type == TokenType.Auto) {
		auto at = new ir.AutoType();
		at.location = ps.peek.location;
		ps.get();
		newExp.type = at;
	} else {
		succeeded = parseType(ps, newExp.type);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
	}

	if (matchIf(ps, TokenType.OpenParen)) {
		newExp.hasArgumentList = true;
		succeeded = _parseArgumentList(ps, newExp.argumentList);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Unary);
		}
		succeeded = match(ps, ir.NodeType.Unary, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
	}

	newExp.location = ps.peek.location - start.location;
	return Succeeded;
}

ParseStatus parseCastExp(ParserStream ps, out intir.CastExp exp)
{
	if (ps != [TokenType.Cast, TokenType.OpenParen]) {
		return unexpectedToken(ps, ir.NodeType.Unary);
	}
	auto start = ps.get();
	ps.get();

	exp = new intir.CastExp();
	auto succeeded = parseType(ps, exp.type);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Unary);
	}

	Token stop;
	succeeded = match(ps, ir.NodeType.Unary, TokenType.CloseParen, stop);
	if (!succeeded) {
		return succeeded;
	}
	exp.location = stop.location - start.location;

	succeeded = parseUnaryExp(ps, exp.unaryExp);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Unary);
	}

	return Succeeded;
}

ParseStatus parsePostfixExp(ParserStream ps, out intir.PostfixExp exp, int depth=0)
{
	depth++;
	exp = new intir.PostfixExp();
	auto origin = ps.peek.location;
	if (depth == 1) {
		auto succeeded = parsePrimaryExp(ps, exp.primary);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
	}

	switch (ps.peek.type) {
	case TokenType.Dot:
		ps.get();
		auto twoAhead = ps.lookahead(2).type;
		if (ps.lookahead(1).type == TokenType.Bang &&
			twoAhead != TokenType.Is && twoAhead != TokenType.Assign) {
			auto succeeded = parseExp(ps, exp.templateInstance);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Postfix);
			}
			break;
		}
		auto succeeded = parseIdentifier(ps, exp.identifier);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
		exp.op = ir.Postfix.Op.Identifier;
		succeeded = parsePostfixExp(ps, exp.postfix, depth);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
		break;
	case TokenType.DoublePlus:
		ps.get();
		exp.op = ir.Postfix.Op.Increment;
		auto succeeded = parsePostfixExp(ps, exp.postfix, depth);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
		break;
	case TokenType.DoubleDash:
		ps.get();
		exp.op = ir.Postfix.Op.Decrement;
		auto succeeded = parsePostfixExp(ps, exp.postfix, depth);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
		break;
	case TokenType.OpenParen:
		ps.get();
		auto succeeded = _parseArgumentList(ps, exp.arguments, exp.labels);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
		succeeded = match(ps, ir.NodeType.Postfix, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
		exp.op = ir.Postfix.Op.Call;
		succeeded = parsePostfixExp(ps, exp.postfix, depth);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
		break;
	case TokenType.OpenBracket:
		ps.get();
		if (ps.peek.type == TokenType.CloseBracket) {
			exp.op = ir.Postfix.Op.Slice;
		} else {
			intir.AssignExp e;
			auto succeeded = parseAssignExp(ps, e);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Postfix);
			}
			exp.arguments ~= e;
			if (ps.peek.type == TokenType.DoubleDot) {
				exp.op = ir.Postfix.Op.Slice;
				ps.get();
				succeeded = parseAssignExp(ps, e);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.Postfix);
				}
				exp.arguments ~= e;
			} else {
				exp.op = ir.Postfix.Op.Index;
				if (ps.peek.type == TokenType.Comma) {
					ps.get();
				}
				intir.AssignExp[] aexps;
				succeeded = _parseArgumentList(ps, aexps, TokenType.CloseBracket);
				exp.arguments ~= aexps;
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.Postfix);
				}
			}
		}
		auto succeeded = match(ps, ir.NodeType.Postfix, TokenType.CloseBracket);
		if (!succeeded) {
			return succeeded;
		}
		succeeded = parsePostfixExp(ps, exp.postfix, depth);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Postfix);
		}
		break;
	default:
		break;
	}

	return Succeeded;
}

ParseStatus parsePrimaryExp(ParserStream ps, out intir.PrimaryExp exp)
{
	exp = new intir.PrimaryExp();
	auto origin = ps.peek.location;
	switch (ps.peek.type) {
	case TokenType.Identifier:
		if (ps == [TokenType.Identifier, TokenType.Assign, TokenType.Greater]) {
			goto case TokenType.Delegate;
		}
		auto token = ps.get();
		if (ps.peek.type == TokenType.Bang && ps.lookahead(1).type != TokenType.Is) {
			ps.get();
			exp.op = intir.PrimaryExp.Type.TemplateInstance;
			exp._template = new ir.TemplateInstanceExp();
			exp._template.location = origin;
			exp._template.name = token.value;
			if (matchIf(ps, TokenType.OpenParen)) {
				while (ps.peek.type != ir.TokenType.CloseParen) {
					ir.TemplateInstanceExp.TypeOrExp tOrE;
					auto succeeded = parseType(ps, tOrE.type);
					if (!succeeded) {
						if (ps.neverIgnoreError) {
							return Failed;
						}
						ps.resetErrors();
						succeeded = parseExp(ps, tOrE.exp);
						if (!succeeded) {
							return parseFailed(ps, ir.NodeType.TemplateInstanceExp);
						}
					}
					exp._template.types ~= tOrE;
					matchIf(ps, TokenType.Comma);
				}
				auto succeeded = match(ps, ir.NodeType.TemplateInstanceExp, TokenType.CloseParen);
				if (!succeeded) {
					return succeeded;
				}
			} else {
				ir.TemplateInstanceExp.TypeOrExp tOrE;
				try {
					auto succeeded = parseType(ps, tOrE.type);
					if (!succeeded) {
						return parseFailed(ps, ir.NodeType.TemplateInstanceExp);
					}
				} catch (CompilerError) {
					auto succeeded = parseExp(ps, tOrE.exp);
					if (!succeeded) {
						return parseFailed(ps, ir.NodeType.TemplateInstanceExp);
					}
				}
				exp._template.types ~= tOrE;
			}
			break;
		}
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.Identifier;
		break;
	case TokenType.Dot:
		ps.get();
		Token token;  // token
		auto succeeded = match(ps, ir.NodeType.IdentifierExp, TokenType.Identifier, token);
		if (!succeeded) {
			return succeeded;
		}
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.DotIdentifier;
		break;
	case TokenType.This:
		ps.get();
		exp.op = intir.PrimaryExp.Type.This;
		break;
	case TokenType.Super:
		ps.get();
		exp.op = intir.PrimaryExp.Type.Super;
		break;
	case TokenType.Null:
		ps.get();
		exp.op = intir.PrimaryExp.Type.Null;
		break;
	case TokenType.True:
		ps.get();
		exp.op = intir.PrimaryExp.Type.True;
		break;
	case TokenType.False:
		ps.get();
		exp.op = intir.PrimaryExp.Type.False;
		break;
	case TokenType.Dollar:
		ps.get();
		exp.op = intir.PrimaryExp.Type.Dollar;
		break;
	case TokenType.IntegerLiteral:
		auto token = ps.get();
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.IntegerLiteral;
		break;
	case TokenType.FloatLiteral:
		auto token = ps.get();
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.FloatLiteral;
		break;
	case TokenType.StringLiteral:
		auto token = ps.get();
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.StringLiteral;
		break;
	case TokenType.__File__:
		auto token = ps.get();
		exp.op = intir.PrimaryExp.Type.File;
		break;
	case TokenType.__Line__:
		auto token = ps.get();
		exp.op = intir.PrimaryExp.Type.Line;
		break;
	case TokenType.__Function__:
		auto token = ps.get();
		exp.op = intir.PrimaryExp.Type.FunctionName;
		break;
	case TokenType.__Pretty_Function__:
		auto token = ps.get();
		exp.op = intir.PrimaryExp.Type.PrettyFunctionName;
		break;
	case TokenType.CharacterLiteral:
		auto token = ps.get();
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.CharLiteral;
		break;
	case TokenType.Assert:
		ps.get();
		auto succeeded = match(ps, ir.NodeType.Assert, TokenType.OpenParen);
		if (!succeeded) {
			return succeeded;
		}
		intir.AssignExp e;
		succeeded = parseAssignExp(ps, e);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Assert);
		}
		exp.arguments ~= e;
		if (ps.peek.type == TokenType.Comma) {
			ps.get();
			succeeded = parseAssignExp(ps, e);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Assert);
			}
			exp.arguments ~= e;
		}
		succeeded = match(ps, ir.NodeType.Assert, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
		exp.op = intir.PrimaryExp.Type.Assert;
		break;
	case TokenType.Import:
		ps.get();
		auto succeeded = match(ps, ir.NodeType.StringImport, TokenType.OpenParen);
		if (!succeeded) {
			return succeeded;
		}
		intir.AssignExp e;
		succeeded = parseAssignExp(ps, e);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.StringImport);
		}
		exp.arguments ~= e;
		succeeded = match(ps, ir.NodeType.StringImport, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
		exp.op = intir.PrimaryExp.Type.Import;
		break;
	case TokenType.OpenBracket:
		size_t i;
		bool isAA;
		while (ps.lookahead(i).type != TokenType.CloseBracket) {
			if (ps.lookahead(i).type == TokenType.Colon) {
				isAA = true;
			}
			i++;
			if (ps.lookahead(i).type == TokenType.Comma ||
				ps.lookahead(i).type == TokenType.End) {
				break;
			}
		}
		if (!isAA) {
			ps.get();
			intir.AssignExp[] aexps;
			auto succeeded = _parseArgumentList(ps, aexps, TokenType.CloseBracket);
			exp.arguments ~= aexps;
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.ArrayLiteral);
			}
			succeeded = match(ps, ir.NodeType.ArrayLiteral, TokenType.CloseBracket);
			if (!succeeded) {
				return succeeded;
			}
			exp.op = intir.PrimaryExp.Type.ArrayLiteral;
		} else {
			ps.get();
			while (ps.peek.type != TokenType.CloseBracket) {
				intir.AssignExp e;
				auto succeeded = parseAssignExp(ps, e);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.ArrayLiteral);
				}
				exp.keys ~= e;
				succeeded = match(ps, ir.NodeType.AssocArray, TokenType.Colon);
				if (!succeeded) {
					return succeeded;
				}
				succeeded = parseAssignExp(ps, e);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.ArrayLiteral);
				}
				exp.arguments ~= e;
				matchIf(ps, TokenType.Comma);
			}
			auto succeeded = match(ps, ir.NodeType.AssocArray, TokenType.CloseBracket);
			if (!succeeded) {
				return succeeded;
			}
			assert(exp.keys.length == exp.arguments.length);
			exp.op = intir.PrimaryExp.Type.AssocArrayLiteral;
		}
		break;
	case TokenType.OpenParen:
		if (isFunctionLiteral(ps)) {
			goto case TokenType.Delegate;
		}
		ps.get();
		if (isUnambiguouslyParenType(ps)) {
			exp.op = intir.PrimaryExp.Type.Type;
			auto succeeded = parseType(ps, exp.type);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TypeExp);
			}
			succeeded = match(ps, ir.NodeType.TypeExp, [TokenType.CloseParen, TokenType.Dot]);
			if (!succeeded) {
				return succeeded;
			}
			if (matchIf(ps, TokenType.Typeid)) {
				exp.op = intir.PrimaryExp.Type.Typeid;
			} else {
				Token nameTok;
				succeeded = match(ps, ir.NodeType.TypeExp, TokenType.Identifier, nameTok);
				if (!succeeded) {
					return succeeded;
				}
				exp._string = nameTok.value;
			}
			break;
		}
		intir.AssignExp e;
		auto succeeded = parseAssignExp(ps, e);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TypeExp);
		}
		exp.tlargs ~= e;
		succeeded = match(ps, ir.NodeType.Invalid, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
		exp.op = intir.PrimaryExp.Type.ParenExp;
		break;
	case TokenType.Bool, TokenType.Ubyte, TokenType.Byte,
		 TokenType.Short, TokenType.Ushort,
		 TokenType.Int, TokenType.Uint, TokenType.Long,
		 TokenType.Ulong, TokenType.Void, TokenType.Float,
		 TokenType.Double, TokenType.Real, TokenType.Char,
		 TokenType.Wchar, TokenType.Dchar:
		exp.op = intir.PrimaryExp.Type.Type;
		exp.type = parsePrimitiveType(ps);
		auto succeeded = match(ps, ir.NodeType.Constant, TokenType.Dot);
		if (!succeeded) {
			return succeeded;
		}
		if (matchIf(ps, TokenType.Typeid)) {
			exp.op = intir.PrimaryExp.Type.Typeid;
		} else {
			Token nameTok;
			succeeded = match(ps, ir.NodeType.Constant, TokenType.Identifier, nameTok);
			if (!succeeded) {
				return succeeded;
			}
			exp._string = nameTok.value;
		}
		break;
	case TokenType.OpenBrace:
		ps.get();
		exp.op = intir.PrimaryExp.Type.StructLiteral;
		while (ps.peek.type != TokenType.CloseBrace) {
			intir.AssignExp e;
			auto succeeded = parseAssignExp(ps, e);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.StructLiteral);
			}
			exp.arguments ~= e;
			matchIf(ps, TokenType.Comma);
		}
		auto succeeded = match(ps, ir.NodeType.StructLiteral, TokenType.CloseBrace);
		if (!succeeded) {
			return succeeded;
		}
		break;
	case TokenType.Typeid:
		ps.get();
		exp.op = intir.PrimaryExp.Type.Typeid;
		auto succeeded = match(ps, ir.NodeType.Typeid, TokenType.OpenParen);
		if (!succeeded) {
			return succeeded;
		}
		if (ps.peek.type == TokenType.Identifier) {
			auto nameTok = ps.get();
			exp._string = nameTok.value;
		} else {
			auto mark = ps.save();
			succeeded = parseType(ps, exp.type);
			if (!succeeded) {
				if (ps.neverIgnoreError) {
					return Failed;
				}
				ps.restore(mark);
				ps.resetErrors();
				succeeded = parseExp(ps, exp.exp);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.Typeid);
				}
			}
		}
		succeeded = match(ps, ir.NodeType.Typeid, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
		break;
	case TokenType.Is:
		exp.op = intir.PrimaryExp.Type.Is;
		auto succeeded = parseIsExp(ps, exp.isExp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.BinOp);
		}
		break;
	case TokenType.Function, TokenType.Delegate:
		exp.op = intir.PrimaryExp.Type.FunctionLiteral;
		auto succeeded = parseFunctionLiteral(ps, exp.functionLiteral);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.FunctionLiteral);
		}
		break;
	case TokenType.__Traits:
		exp.op = intir.PrimaryExp.Type.Traits;
		auto succeeded = parseTraitsExp(ps, exp.trait);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Invalid);
		}
		break;
	case TokenType.VaArg:
		exp.op = intir.PrimaryExp.Type.VaArg;
		auto succeeded = parseVaArgExp(ps, exp.vaexp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Function);
		}
		break;
	default:
		auto mark = ps.save();
		auto succeeded = parseFunctionLiteral(ps, exp.functionLiteral);
		if (!succeeded) {
			ps.restore(mark);
			// The dreaded "expected primary expression" error.
			return unexpectedToken(ps, ir.NodeType.Invalid);
		}
		exp.op = intir.PrimaryExp.Type.FunctionLiteral;
		break;
	}

	exp.location = ps.peek.location - origin;

	if (ps == [TokenType.Dot, TokenType.Typeid] && exp.op != intir.PrimaryExp.Type.Typeid) {
		ps.get();
		ps.get();
		auto succeeded = primaryToExp(ps, exp, exp.exp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Typeid);
		}
		exp.op = intir.PrimaryExp.Type.Typeid;
		assert(exp.type is null);
	}
	
	return Succeeded;
}

ParseStatus parseVaArgExp(ParserStream ps, out ir.VaArgExp vaexp)
{
	vaexp = new ir.VaArgExp();
	vaexp.location = ps.peek.location;
	auto succeeded = match(ps, ir.NodeType.VaArgExp, [TokenType.VaArg, TokenType.Bang]);
	if (!succeeded) {
		return succeeded;
	}
	bool paren = matchIf(ps, TokenType.OpenParen);
	succeeded = parseType(ps, vaexp.type);
	if (!succeeded) {
		return parseFailed(ps, vaexp);
	}
	if (paren) {
		succeeded = match(ps, ir.NodeType.VaArgExp, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
	}
	succeeded = match(ps, ir.NodeType.VaArgExp, TokenType.OpenParen);
	if (!succeeded) {
		return succeeded;
	}
	succeeded = parseExp(ps, vaexp.arg);
	if (!succeeded) {
		return parseFailed(ps, vaexp);
	}
	succeeded = match(ps, ir.NodeType.VaArgExp, TokenType.CloseParen);
	if (!succeeded) {
		return succeeded;
	}
	return Succeeded;
}

bool isUnambiguouslyParenType(ParserStream ps)
{
	switch (ps.peek.type) with (TokenType) {
	case Bool, Byte, Short, Int, Long,
		 Char, Ubyte, Ushort, Uint, Ulong,
		 Dchar, Wchar, Void:
		return true;
	default:
		return false;
	}
}

// Returns: true if the ParserStream is at a function literal.
bool isFunctionLiteral(ParserStream ps)
{
	if (ps.peek.type == TokenType.Function || ps.peek.type == TokenType.Delegate) {
		return true;
	}
	auto mark = ps.save();
	if (ps.peek.type != TokenType.OpenParen) {
		ir.Type tmp;
		return parseType(ps, tmp) == Succeeded;
	}

	assert(ps.peek.type == TokenType.OpenParen);
	int parenDepth;
	while (!(parenDepth == 0 && ps.peek.type == TokenType.CloseParen)) {
		ps.get();
		if (ps.peek.type == TokenType.OpenParen) {
			parenDepth++;
		}
		if (ps.peek.type == TokenType.CloseParen && parenDepth > 0) {
			parenDepth--;
		}
	}
	ps.get();  // Eat the close paren.

	if (ps.peek.type == TokenType.OpenBrace) {
		ps.restore(mark);
		return true;
	} else if (ps == [TokenType.Assign, TokenType.Greater]) {
		ps.restore(mark);
		return true;
	} else {
		ps.restore(mark);
		return false;
	}
	assert(false);
}
