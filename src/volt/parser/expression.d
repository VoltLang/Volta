// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.expression;
// Most of these can pass through to a lower function, see the IR.

import std.conv;

import ir = volt.ir.ir;
import intir = volt.parser.intir;

import volt.exceptions;
import volt.token.location;
import volt.token.stream;
import volt.parser.base;
import volt.parser.declaration;
import volt.util.string;


ir.Exp parseExp(TokenStream ts)
{
	auto ternaryExp = parseTernaryExp(ts);
	return ternaryToExp(ternaryExp);
}

/// Starts parsing at BinExp. Certain constructs need this.
ir.Exp parseAssignExp(TokenStream ts)
{
	auto binexp = parseBinExp(ts);
	return binexpToExp(binexp);
}

ir.Exp ternaryToExp(intir.TernaryExp tern)
{
	if (tern.ifTrue !is null) {
		auto exp = new ir.Ternary();
		exp.location = tern.location;
		exp.condition = binexpToExp(tern.condition);
		exp.ifTrue = ternaryToExp(tern.ifTrue);
		exp.ifFalse = ternaryToExp(tern.ifFalse);
		return exp;
	} else {
		return binexpToExp(tern.condition);
	}
	assert(false);
}

class ExpOrOp
{
	intir.UnaryExp exp;
	ir.BinOp.Type op;
	ir.BinOp bin;

	this(intir.UnaryExp exp)
	{
		this.exp = exp;
	}

	this(ir.BinOp.Type op)
	{
		this.op = op;
	}

	bool isExp()
	{
		return exp !is null;
	}
}

ExpOrOp[] gatherExps(intir.BinExp bin)
{
	ExpOrOp[] list;
	while (bin.op != ir.BinOp.Type.None) {
		list ~= new ExpOrOp(bin.left);
		list ~= new ExpOrOp(bin.op);
		bin = bin.right;
	}
	list ~= new ExpOrOp(bin.left);
	return list;
}

ExpOrOp[] expressionsAsPostfix(intir.BinExp bin)
{
	// Ladies and gentlemen, Mr. Edsger Dijkstra's shunting-yard algorithm! (polite applause)
	ExpOrOp[] infix = gatherExps(bin);
	ExpOrOp[] postfix;
	ir.BinOp.Type[] operationStack;

	foreach (element; infix) {
		if (element.isExp) {
			postfix ~= element;
			continue;
		}
		while (operationStack.length > 0) {
			auto op = operationStack[0];
			if ((intir.isLeftAssociative(element.op) && intir.getPrecedence(element.op) <= intir.getPrecedence(operationStack[0])) ||
				(!intir.isLeftAssociative(element.op) && intir.getPrecedence(element.op) < intir.getPrecedence(operationStack[0]))) {
				postfix ~= new ExpOrOp(operationStack[0]);
				operationStack = operationStack[1 .. $];
			} else {
				break;
			}
		}

		operationStack = [element.op] ~ operationStack;
	}

	while (operationStack.length > 0) {
		postfix ~= new ExpOrOp(operationStack[0]);
		operationStack = operationStack[1 .. $];
	}

	return postfix;
}

ir.Exp binexpToExp(intir.BinExp bin)
{
	if (bin.op == ir.BinOp.Type.None) {
		return unaryToExp(bin.left);
	}

	ExpOrOp[] postfix = expressionsAsPostfix(bin);
	intir.UnaryExp[] exps;
	ir.BinOp binout;

	foreach (el; postfix) {
		if (el.isExp) {
			exps = el.exp ~ exps;
		} else {
			if (binout is null) {
				binout = new ir.BinOp();
				binout.op = el.op;
				binout.left = unaryToExp(exps[1]);
				binout.right = unaryToExp(exps[0]);
				exps = exps[2..$];
			} else {
				auto b = new ir.BinOp();
				b.op = el.op;
				if (intir.isLeftAssociative(b.op)) {
					b.left =  binout;
					b.right = unaryToExp(exps[0]);
				} else {
					b.left = unaryToExp(exps[0]);
					b.right = binout;
				}
				binout = b;
			}
		}
	}
	binout.location = bin.location;
	return binout;
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
		if (unary.newExp.isArray) {
			auto asStaticArray = cast(ir.StaticArrayType) unary.newExp.type;
			exp.type = asStaticArray.base;
			auto constant = new ir.Constant();
			constant.location = unary.newExp.location;
			constant.value = to!string(asStaticArray.length);
			constant.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Uint);
			exp.index = constant;
			exp.isArray = true;
		} else if (unary.newExp.hasArgumentList) {
			exp.hasArgumentList = true;
			foreach (arg; unary.newExp.argumentList) {
				exp.argumentList ~= binexpToExp(arg);
			}
		}
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
		if (exp.op == ir.Postfix.Op.Identifier) {
			assert(postfix.identifier !is null);
			exp.identifier = postfix.identifier;
		} else foreach (arg; postfix.arguments) {
			exp.arguments ~= binexpToExp(arg);
		}
		return postfixToExp(location, postfix.postfix, exp);
	}
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
		c.value = "null";
		c.type = new ir.PointerType(new ir.PrimitiveType(ir.PrimitiveType.Kind.Void));
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.Dollar:
		auto c = new ir.Constant();
		c.value = "$";
		c.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Uint);
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.True:
		auto c = new ir.Constant();
		c.value = "true";
		c.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.False:
		auto c = new ir.Constant();
		c.value = "false";
		c.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.Typeid:
		auto ti = new ir.Typeid();
		if (primary.exp !is null) {
			ti.exp = primary.exp;
		} else {
			ti.type = primary.type;
		}
		exp = ti;
		break;
	case intir.PrimaryExp.Type.StringLiteral:
		auto c = new ir.Constant();
		c.value = primary._string;
		c.type = new ir.ArrayType(new ir.PrimitiveType(ir.PrimitiveType.Kind.Char));
		c.type.location = primary.location;
		assert(c.value[$-1] == '"' && c.value.length >= 3);
		c.arrayData = unescapeString(primary.location, c.value[1 .. $-1]);
		exp = c;
		break;
	case intir.PrimaryExp.Type.CharLiteral:
		auto c = new ir.Constant();
		c.value = primary._string;
		c.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Char);
		c.type.location = primary.location;
		assert(c.value[$-1] == '\'' && c.value.length >= 3);
		c.arrayData = unescapeString(primary.location, c.value[1 .. $-1]);
		exp = c;
		break;
	case intir.PrimaryExp.Type.FloatLiteral:
		auto c = new ir.Constant();
		c.value = primary._string;
		c.type = new ir.PrimitiveType(ir.PrimitiveType.Kind.Float);
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.IntegerLiteral:
		auto c = new ir.Constant();
		c.value = primary._string;
		auto base = ir.PrimitiveType.Kind.Int;

		// If there are any suffixes, change the type to match.
		while (c.value[$-1] == 'u' || c.value[$-1] == 'U' ||
			   c.value[$-1] == 'L') {
			if (c.value[$-1] == 'u' || c.value[$-1] == 'U') {
				if (base == ir.PrimitiveType.Kind.Long) {
					base = ir.PrimitiveType.Kind.Ulong;
				} else {
					base = ir.PrimitiveType.Kind.Uint;
				}
			} else if (c.value[$-1] == 'L') {
				if (base == ir.PrimitiveType.Kind.Uint) {
					base = ir.PrimitiveType.Kind.Ulong;
				} else {
					base = ir.PrimitiveType.Kind.Long;
				}
			}
			c.value = c.value[0 .. $-1];
		}

		c.type = new ir.PrimitiveType(base);
		c.type.location = primary.location;
		exp = c;
		break;
	case intir.PrimaryExp.Type.ParenExp:
		assert(primary.tlargs.length == 1);
		return ternaryToExp(primary.tlargs[0]);
	case intir.PrimaryExp.Type.ArrayLiteral:
		auto c = new ir.ArrayLiteral();
		foreach (arg; primary.arguments) {
			c.values ~= binexpToExp(arg);
		}
		exp = c;
		break;
	case intir.PrimaryExp.Type.AssocArrayLiteral:
		auto c = new ir.AssocArray();
		for (size_t i = 0; i < primary.keys.length; ++i) {
			c.pairs ~= new ir.AAPair(binexpToExp(primary.keys[i]), binexpToExp(primary.arguments[i]));
			c.pairs[$-1].location = primary.keys[i].location;
		}
		exp = c;
		break;
	case intir.PrimaryExp.Type.Assert:
		auto c = new ir.Assert();
		c.condition = binexpToExp(primary.arguments[0]);
		if (primary.arguments.length >= 2) {
			c.message = binexpToExp(primary.arguments[1]);
		}
		exp = c;
		break;
	case intir.PrimaryExp.Type.Import:
		auto c = new ir.StringImport();
		c.filename = binexpToExp(primary.arguments[0]);
		exp = c;
		break;
	case intir.PrimaryExp.Type.Is:
		return primary.isExp;
	case intir.PrimaryExp.Type.FunctionLiteral:
		return primary.functionLiteral;
	case intir.PrimaryExp.Type.StructLiteral:
		auto lit = new ir.StructLiteral();
		foreach (bexp; primary.arguments) {
			lit.exps ~= binexpToExp(bexp);
		}
		exp = lit;
		break;
	default:
		throw CompilerPanic(primary.location, "unhandled primary expression.");
	}

	exp.location = primary.location;
	return exp;
}

private intir.BinExp[] _parseArgumentList(TokenStream ts, TokenType endChar = TokenType.CloseParen)
{
	intir.BinExp[] pexps;
	while (ts.peek.type != endChar) {
		if (ts.peek.type == TokenType.End) {
			throw new CompilerError(ts.peek.location, "unexpected EOF when parsing argument list.");
		}
		pexps ~= parseBinExp(ts);
		if (ts.peek.type != endChar) {
			match(ts, TokenType.Comma);
		}
	}

	return pexps;
}

// Parse an argument list from ts. Will end with ts.peek == endChar.
ir.Exp[] parseArgumentList(TokenStream ts, TokenType endChar = TokenType.CloseParen)
{
	intir.BinExp[] pexps = _parseArgumentList(ts, endChar);

	ir.Exp[] outexps;
	foreach (exp; pexps) {
		outexps ~= binexpToExp(exp);
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
				throw new CompilerError(ts.peek.location, "malformed is expression.");
			}
			auto nameTok = match(ts, Identifier);
			ie.identifier = nameTok.value;
			break;
		case Colon:
			if (ie.compType != ir.IsExp.Comparison.None) {
				throw new CompilerError(ts.peek.location, "malformed is expression.");
			}
			ts.get();
			ie.compType = ir.IsExp.Comparison.Implicit;
			break;
		case DoubleAssign:
			if (ie.compType != ir.IsExp.Comparison.None) {
				throw new CompilerError(ts.peek.location, "malformed is expression.");
			}
			ts.get();
			ie.compType = ir.IsExp.Comparison.Exact;
			break;
		default:
			if (ie.compType == ir.IsExp.Comparison.None) {
				throw new CompilerError(ts.peek.location, "expected '==' or ':' before type specialisation.");
			}
			switch (ts.peek.type) {
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
			throw new CompilerError(ts.peek.location, "malformed lambda expression.", true);
		}
		match(ts, TokenType.Assign);
		match(ts, TokenType.Greater);
		fn.lambdaExp = parseExp(ts);
		return fn;
	} else {
		fn.block = parseBlock(ts);
		return fn;
	}
}

/*** ugly intir stuff ***/

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
			exp.op = ir.BinOp.Type.NotIs;
		} else if (ts.lookahead(1).type == TokenType.In) {
			ts.get();
			exp.op = ir.BinOp.Type.NotIn;
		} else {
			goto default;
		}
		break;
	case TokenType.Assign:
		exp.op = ir.BinOp.Type.Assign; break;
	case TokenType.PlusAssign:
		exp.op = ir.BinOp.Type.AddAssign; break;
	case TokenType.DashAssign:
		exp.op = ir.BinOp.Type.SubAssign; break;
	case TokenType.AsterixAssign:
		exp.op = ir.BinOp.Type.MulAssign; break;
	case TokenType.SlashAssign:
		exp.op = ir.BinOp.Type.DivAssign; break;
	case TokenType.PercentAssign:
		exp.op = ir.BinOp.Type.ModAssign; break;
	case TokenType.AmpersandAssign:
		exp.op = ir.BinOp.Type.AndAssign; break;
	case TokenType.PipeAssign:
		exp.op = ir.BinOp.Type.OrAssign; break;
	case TokenType.CaretAssign:
		exp.op = ir.BinOp.Type.XorAssign; break;
	case TokenType.TildeAssign:
		exp.op = ir.BinOp.Type.CatAssign; break;
	case TokenType.DoubleLessAssign:
		exp.op = ir.BinOp.Type.LSAssign; break;
	case TokenType.DoubleGreaterAssign:
		exp.op = ir.BinOp.Type.SRSAssign; break;
	case TokenType.TripleGreaterAssign:
		exp.op = ir.BinOp.Type.RSAssign; break;
	case TokenType.DoubleCaretAssign:
		exp.op = ir.BinOp.Type.PowAssign; break;
	case TokenType.DoublePipe:
		exp.op = ir.BinOp.Type.OrOr; break;
	case TokenType.DoubleAmpersand:
		exp.op = ir.BinOp.Type.AndAnd; break;
	case TokenType.Pipe:
		exp.op = ir.BinOp.Type.Or; break;
	case TokenType.Caret:
		exp.op = ir.BinOp.Type.Xor; break;
	case TokenType.Ampersand:
		exp.op = ir.BinOp.Type.And; break;
	case TokenType.DoubleAssign:
		exp.op = ir.BinOp.Type.Equal; break;
	case TokenType.BangAssign:
		exp.op = ir.BinOp.Type.NotEqual; break;
	case TokenType.Is:
		exp.op = ir.BinOp.Type.Is; break;
	case TokenType.In:
		exp.op = ir.BinOp.Type.In; break;
	case TokenType.Less:
		exp.op = ir.BinOp.Type.Less; break;
	case TokenType.LessAssign:
		exp.op = ir.BinOp.Type.LessEqual; break;
	case TokenType.Greater:
		exp.op = ir.BinOp.Type.Greater; break;
	case TokenType.GreaterAssign:
		exp.op = ir.BinOp.Type.GreaterEqual; break;
	case TokenType.DoubleLess:
		exp.op = ir.BinOp.Type.LS; break;
	case TokenType.DoubleGreater:
		exp.op = ir.BinOp.Type.SRS; break;
	case TokenType.TripleGreater:
		exp.op = ir.BinOp.Type.RS; break;
	case TokenType.Plus:
		exp.op = ir.BinOp.Type.Add; break;
	case TokenType.Dash:
		exp.op = ir.BinOp.Type.Sub; break;
	case TokenType.Tilde:
		exp.op = ir.BinOp.Type.Cat; break;
	case TokenType.Slash:
		exp.op = ir.BinOp.Type.Div; break;
	case TokenType.Asterix:
		exp.op = ir.BinOp.Type.Mul; break;
	case TokenType.Percent:
		exp.op = ir.BinOp.Type.Mod; break;
	case TokenType.DoubleCaret:
		exp.op = ir.BinOp.Type.Pow; break;
	default:
		exp.op = ir.BinOp.Type.None; break;
	}
	if (exp.op != ir.BinOp.Type.None) {
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
		exp.op = ir.Unary.Op.New;
		exp.newExp = parseNewExp(ts);
		break;
	default:
		exp.postExp = parsePostfixExp(ts);
		break;
	}
	exp.location = ts.peek.location - origin;

	return exp;
}

intir.NewExp parseNewExp(TokenStream ts)
{
	auto start = match(ts, TokenType.New);

	auto newExp = new intir.NewExp();
	newExp.type = parseType(ts);

	if (newExp.type.nodeType == ir.NodeType.StaticArrayType) {
		newExp.isArray = true;
	} else if (matchIf(ts, TokenType.OpenParen)) {
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
		exp.arguments = _parseArgumentList(ts);
		match(ts, TokenType.CloseParen);
		exp.op = ir.Postfix.Op.Call;
		exp.postfix = parsePostfixExp(ts, depth);
		break;
	case TokenType.OpenBracket:
		ts.get();
		if (ts.peek.type == TokenType.CloseBracket) {
			exp.op = ir.Postfix.Op.Slice;
		} else {
			exp.arguments ~= parseBinExp(ts);
			if (ts.peek.type == TokenType.DoubleDot) {
				exp.op = ir.Postfix.Op.Slice;
				ts.get();
				exp.arguments ~= parseBinExp(ts);
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
	case TokenType.CharacterLiteral:
		auto token = ts.get();
		exp._string = token.value;
		exp.op = intir.PrimaryExp.Type.CharLiteral;
		break;
	case TokenType.Assert:
		ts.get();
		match(ts, TokenType.OpenParen);
		exp.arguments ~= parseBinExp(ts);
		if (ts.peek.type == TokenType.Comma) {
			ts.get();
			exp.arguments ~= parseBinExp(ts);
		}
		match(ts, TokenType.CloseParen);
		exp.op = intir.PrimaryExp.Type.Assert;
		break;
	case TokenType.Import:
		ts.get();
		match(ts, TokenType.OpenParen);
		exp.arguments ~= parseBinExp(ts);
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
				exp.keys ~= parseBinExp(ts);
				match(ts, TokenType.Colon);
				exp.arguments ~= parseBinExp(ts);
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
		ts.get();
		exp.tlargs ~= parseTernaryExp(ts);
		match(ts, TokenType.CloseParen);
		exp.op = intir.PrimaryExp.Type.ParenExp;
		break;
	case TokenType.OpenBrace:
		ts.get();
		exp.op = intir.PrimaryExp.Type.StructLiteral;
		while (ts.peek.type != TokenType.CloseBrace) {
			exp.arguments ~= parseBinExp(ts);
			matchIf(ts, TokenType.Comma);
		}
		match(ts, TokenType.CloseBrace);
		break;
	case TokenType.Typeid:
		ts.get();
		exp.op = intir.PrimaryExp.Type.Typeid;
		match(ts, TokenType.OpenParen);
		auto mark = ts.save();
		try {
			auto e = parseType(ts);
			exp.type = e;
		} catch (CompilerError err) {
			if (err.neverIgnore) {
				throw err;
			}
			ts.restore(mark);
			exp.exp = parseExp(ts);
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
	default:
		auto mark = ts.save();
		try {
			exp.op = intir.PrimaryExp.Type.FunctionLiteral;
			exp.functionLiteral = parseFunctionLiteral(ts);
		} catch (CompilerError e) {
			ts.restore(mark);
			throw new CompilerError(ts.peek.location, "Expected primary expression, not '" ~ ts.peek.value ~ "'.");
		}
		break;
	}

	exp.location = ts.peek.location - origin;
	return exp;
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
