// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.statements;

import watt.text.ascii;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy : copyType;

import volt.errors;
import volt.exceptions;
import volt.token.stream;
import volt.token.token : TokenType, Token;

import volt.parser.base;
import volt.parser.declaration;
import volt.parser.expression;
import volt.parser.toplevel;


ParseStatus parseStatement(ParserStream ps, NodeSinkDg dg)
{
	auto succeeded = eatComments(ps);

	switch (ps.peek.type) {
	case TokenType.Semicolon:
		// Just ignore EmptyStatements
		return match(ps, ir.NodeType.Invalid, TokenType.Semicolon);
	case TokenType.Import:
		ir.Import _import;
		succeeded = parseImport(ps, _import);
		if (!succeeded) {
			return succeeded;
		}
		dg(_import);
		return eatComments(ps);
	case TokenType.Return:
		ir.ReturnStatement r;
		succeeded = parseReturnStatement(ps, r);
		if (!succeeded) {
			return succeeded;
		}
		dg(r);
		return eatComments(ps);
	case TokenType.OpenBrace:
		ir.BlockStatement b;
		succeeded = parseBlockStatement(ps, b);
		if (!succeeded) {
			return succeeded;
		}
		dg(b);
		return eatComments(ps);
	case TokenType.Asm:
		ir.AsmStatement a;
		succeeded = parseAsmStatement(ps, a);
		if (!succeeded) {
			return succeeded;
		}
		dg(a);
		return eatComments(ps);
	case TokenType.If:
		ir.IfStatement i;
		succeeded = parseIfStatement(ps, i);
		if (!succeeded) {
			return succeeded;
		}
		dg(i);
		return eatComments(ps);
	case TokenType.While:
		ir.WhileStatement w;
		succeeded = parseWhileStatement(ps, w);
		if (!succeeded) {
			return succeeded;
		}
		dg(w);
		return eatComments(ps);
	case TokenType.Do:
		ir.DoStatement d;
		succeeded = parseDoStatement(ps, d);
		if (!succeeded) {
			return succeeded;
		}
		dg(d);
		return eatComments(ps);
	case TokenType.For:
		ir.ForStatement f;
		succeeded = parseForStatement(ps, f);
		if (!succeeded) {
			return succeeded;
		}
		dg(f);
		return eatComments(ps);
	case TokenType.Foreach, TokenType.ForeachReverse:
		ir.ForeachStatement f;
		succeeded = parseForeachStatement(ps, f);
		if (!succeeded) {
			return succeeded;
		}
		dg(f);
		return eatComments(ps);
	case TokenType.Switch:
		ir.SwitchStatement ss;
		succeeded = parseSwitchStatement(ps, ss);
		if (!succeeded) {
			return succeeded;
		}
		dg(ss);
		return eatComments(ps);
	case TokenType.Break:
		ir.BreakStatement bs;
		succeeded = parseBreakStatement(ps, bs);
		if (!succeeded) {
			return succeeded;
		}
		dg(bs);
		return eatComments(ps);
	case TokenType.Continue:
		ir.ContinueStatement cs;
		succeeded = parseContinueStatement(ps, cs);
		if (!succeeded) {
			return succeeded;
		}
		dg(cs);
		return eatComments(ps);
	case TokenType.Goto:
		ir.GotoStatement gs;
		succeeded = parseGotoStatement(ps, gs);
		if (!succeeded) {
			return succeeded;
		}
		dg(gs);
		return eatComments(ps);
	case TokenType.With:
		ir.WithStatement ws;
		succeeded = parseWithStatement(ps, ws);
		if (!succeeded) {
			return succeeded;
		}
		dg(ws);
		return eatComments(ps);
	case TokenType.Synchronized:
		ir.SynchronizedStatement ss;
		succeeded = parseSynchronizedStatement(ps, ss);
		if (!succeeded) {
			return succeeded;
		}
		dg(ss);
		return eatComments(ps);
	case TokenType.Try:
		ir.TryStatement t;
		succeeded = parseTryStatement(ps, t);
		if (!succeeded) {
			return succeeded;
		}
		dg(t);
		return eatComments(ps);
	case TokenType.Throw:
		ir.ThrowStatement t;
		succeeded = parseThrowStatement(ps, t);
		if (!succeeded) {
			return succeeded;
		}
		dg(t);
		return eatComments(ps);
	case TokenType.Scope:
		if (ps.lookahead(1).type == TokenType.OpenParen && ps.lookahead(2).type == TokenType.Identifier &&
			ps.lookahead(3).type == TokenType.CloseParen) {
			auto identTok = ps.lookahead(2);
			if (identTok.value == "exit" || identTok.value == "failure" || identTok.value == "success") {
				ir.ScopeStatement ss;
				succeeded = parseScopeStatement(ps, ss);
				if (!succeeded) {
					return succeeded;
				}
				dg(ss);
				return eatComments(ps);
			}
		}
		goto default;
	case TokenType.Pragma:
		ir.PragmaStatement prs;
		succeeded = parsePragmaStatement(ps, prs);
		if (!succeeded) {
			return succeeded;
		}
		dg(prs);
		return eatComments(ps);
	case TokenType.Identifier:
		if (ps.lookahead(1).type == TokenType.Colon ||
		    ps.lookahead(1).type == TokenType.ColonAssign ||
			ps.lookahead(1).type == TokenType.Comma) {
			succeeded = parseColonAssign(ps, dg);
			if (!succeeded) {
				return succeeded;
			}
			return eatComments(ps);
		} else {
			goto default;
		}
		version (Volt) assert(false); // If
	case TokenType.Final:
		if (ps.lookahead(1).type == TokenType.Switch) {
			goto case TokenType.Switch;
		} else {
			goto default;
		}
		version (Volt) assert(false); // If/Case
	case TokenType.Static:
		if (ps.lookahead(1).type == TokenType.If) {
			goto case TokenType.Version;
		} else if (ps.lookahead(1).type == TokenType.Assert) {
			goto case TokenType.Assert;
		} else if (ps.lookahead(1).type == TokenType.Is) {
			ir.AssertStatement as;
			succeeded = parseStaticIs(ps, as);
			if (!succeeded) {
				return succeeded;
			}
			dg(as);
			return eatComments(ps);
		} else {
			goto default;
		}
		version (Volt) assert(false); // If/Case
	case TokenType.Assert:
		ir.AssertStatement a;
		succeeded = parseAssertStatement(ps, a);
		if (!succeeded) {
			return succeeded;
		}
		dg(a);
		return eatComments(ps);
	case TokenType.Version:
	case TokenType.Debug:
		ir.ConditionStatement cs;
		succeeded = parseConditionStatement(ps, cs);
		if (!succeeded) {
			return succeeded;
		}
		dg(cs);
		return eatComments(ps);
	case TokenType.Mixin:
		ir.MixinStatement ms;
		succeeded = parseMixinStatement(ps, ms);
		if (!succeeded) {
			return succeeded;
		}
		dg(ms);
		return eatComments(ps);
	default:
		// It is safe to just set succeeded like this since
		// only variable returns more then one node.
		void func(ir.Node n) {
			auto exp = cast(ir.Exp)n;
			if (exp is null) {
				dg(n);
				return;
			}

			succeeded = match(ps, ir.NodeType.ExpStatement, TokenType.Semicolon);
			if (!succeeded) {
				return;
			}

			auto es = new ir.ExpStatement();
			es.location = exp.location;
			es.exp = exp;
			dg(es);
		}

		version (Volt) {
			auto succeeded2 = parseVariableOrExpression(ps, cast(NodeSinkDg)func);
		} else {
			auto succeeded2 = parseVariableOrExpression(ps, &func);
		}

		if (!succeeded || !succeeded2) {
			return Failed;
		}
		succeeded = succeeded2;
		return eatComments(ps);
	}
	version (Volt) assert(false); // If
}

/* Try to parse as a declaration first because
 *   Object* a;
 * Is always a declaration. If you do something like
 *   int a, b;
 *   a * b;
 * An error like "a used as type" should be emitted.
 */
ParseStatus parseVariableOrExpression(ParserStream ps, NodeSinkDg dg)
{
	size_t pos = ps.save();
	auto succeeded = parseVariable(ps, dg);
	if (succeeded) {
		return Succeeded;
	}

	if (ps.neverIgnoreError) {
		return Failed;
	}

	ps.restore(pos);
	ps.resetErrors();
	ir.Function func;
	ir.Type base;
	succeeded = parseType(ps, base);
	if (succeeded) {
		succeeded = parseFunction(ps, func, base);
		if (succeeded) {
			dg(func);
			return Succeeded;
		}
	}

	if (ps.neverIgnoreError) {
		return Failed;
	}

	ps.restore(pos);
	ps.resetErrors();

	ir.Exp e;
	succeeded = parseExp(ps, e);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Variable);
	}
	dg(e);
	return Succeeded;
}

ParseStatus parseAssertStatement(ParserStream ps, out ir.AssertStatement as)
{
	as = new ir.AssertStatement();
	as.location = ps.peek.location;
	as.isStatic = matchIf(ps, TokenType.Static);
	if (ps != TokenType.Assert) {
		return unexpectedToken(ps, as);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, as);
	}
	ps.get();
	auto succeeded = parseExp(ps, as.condition);
	if (!succeeded) {
		return parseFailed(ps, as);
	}
	if (matchIf(ps, TokenType.Comma)) {
		succeeded = parseExp(ps, as.message);
		if (!succeeded) {
			return parseFailed(ps, as);
		}
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, as);
	}
	ps.get();
	if (ps != TokenType.Semicolon) {
		return unexpectedToken(ps, as);
	}
	ps.get();
	return Succeeded;
}

ParseStatus parseExpStatement(ParserStream ps, out ir.ExpStatement e)
{
	e = new ir.ExpStatement();
	e.location = ps.peek.location;

	auto succeeded = parseExp(ps, e.exp);
	if (!succeeded) {
		return parseFailed(ps, e);
	}
	succeeded = eatComments(ps);
	if (!succeeded) {
		return succeeded;
	}
	if (ps != TokenType.Semicolon) {
		return unexpectedToken(ps, e);
	}
	ps.get();

	return Succeeded;
}

ParseStatus parseReturnStatement(ParserStream ps, out ir.ReturnStatement r)
{
	r = new ir.ReturnStatement();
	r.location = ps.peek.location;

	if (ps != TokenType.Return) {
		return unexpectedToken(ps, r);
	}
	ps.get();

	// return;
	if (matchIf(ps, TokenType.Semicolon)) {
		return Succeeded;
	}

	auto succeeded = parseExp(ps, r.exp);
	if (!succeeded) {
		return parseFailed(ps, r);
	}
	if (ps != TokenType.Semicolon) {
		return unexpectedToken(ps, r);
	}
	ps.get();

	return Succeeded;
}

ParseStatus parseBlockStatement(ParserStream ps, out ir.BlockStatement bs)
{
	bs = new ir.BlockStatement();
	bs.location = ps.peek.location;

	ps.pushCommentLevel();

	auto sink = new NodeSink();
	if (matchIf(ps, TokenType.OpenBrace)) {
		while (ps != TokenType.CloseBrace) {
			auto succeeded = parseStatement(ps, sink.push);
			if (!succeeded) {
				return parseFailed(ps, bs);
			}
		}
		if (ps != TokenType.CloseBrace) {
			return unexpectedToken(ps, bs);
		}
		ps.get();
	} else {
		// Okay to send in directly.
		auto succeeded = parseStatement(ps, sink.push);
		if (!succeeded) {
			return parseFailed(ps, bs);
		}
	}

	bs.statements = sink.array;
	ps.popCommentLevel();

	return Succeeded;
}

ParseStatus parseAsmStatement(ParserStream ps, out ir.AsmStatement as)
{
	as = new ir.AsmStatement();
	as.location = ps.peek.location;

	if (ps != TokenType.Asm) {
		return unexpectedToken(ps, as);
	}
	ps.get();
	if (ps != TokenType.OpenBrace) {
		return unexpectedToken(ps, as);
	}
	ps.get();
	while (ps != TokenType.CloseBrace) {
		as.tokens ~= ps.get();
	}
	if (ps != TokenType.CloseBrace) {
		return unexpectedToken(ps, as);
	}
	ps.get();

	return Succeeded;
}

ParseStatus parseIfStatement(ParserStream ps, out ir.IfStatement i)
{
	i = new ir.IfStatement();
	i.location = ps.peek.location;

	if (ps != TokenType.If) {
		return unexpectedToken(ps, i);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, i);
	}
	ps.get();
	if (matchIf(ps, TokenType.Auto)) {
		if (ps != TokenType.Identifier) {
			return unexpectedToken(ps, i);
		}
		auto nameTok = ps.get();
		i.autoName = nameTok.value;
		if (ps != TokenType.Assign) {
			return unexpectedToken(ps, i);
		}
		ps.get();
	}
	auto succeeded = parseExp(ps, i.exp);
	if (!succeeded) {
		return parseFailed(ps, i);
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, i);
	}
	ps.get();
	succeeded = parseBlockStatement(ps, i.thenState);
	if (!succeeded) {
		return parseFailed(ps, i);
	}
	if (matchIf(ps, TokenType.Else)) {
		succeeded = parseBlockStatement(ps, i.elseState);
		if (!succeeded) {
			return parseFailed(ps, i);
		}
	}

	return Succeeded;
}

ParseStatus parseWhileStatement(ParserStream ps, out ir.WhileStatement w)
{
	w = new ir.WhileStatement();
	w.location = ps.peek.location;

	if (ps != TokenType.While) {
		return unexpectedToken(ps, w);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, w);
	}
	ps.get();
	auto succeeded = parseExp(ps, w.condition);
	if (!succeeded) {
		return parseFailed(ps, w);
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, w);
	}
	ps.get();
	succeeded = parseBlockStatement(ps, w.block);
	if (!succeeded) {
		return parseFailed(ps, w);
	}

	return Succeeded;
}

ParseStatus parseDoStatement(ParserStream ps, out ir.DoStatement d)
{
	d = new ir.DoStatement();
	d.location = ps.peek.location;

	if (ps != TokenType.Do) {
		return unexpectedToken(ps, d);
	}
	ps.get();
	auto succeeded = parseBlockStatement(ps, d.block);
	if (!succeeded) {
		return parseFailed(ps, d);
	}
	if (ps != TokenType.While) {
		return unexpectedToken(ps, d);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, d);
	}
	ps.get();
	succeeded = parseExp(ps, d.condition);
	if (!succeeded) {
		return parseFailed(ps, d);
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, d);
	}
	ps.get();
	if (ps != TokenType.Semicolon) {
		return unexpectedToken(ps, d);
	}
	ps.get();

	return Succeeded;
}

ParseStatus parseForeachStatement(ParserStream ps, out ir.ForeachStatement f)
{
	f = new ir.ForeachStatement();
	f.location = ps.peek.location;

	f.reverse = matchIf(ps, TokenType.ForeachReverse);
	if (!f.reverse) {
		if (ps != TokenType.Foreach) {
			return unexpectedToken(ps, f);
		}
		ps.get();
	}
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, f);
	}
	ps.get();

	if (ps != [TokenType.IntegerLiteral, TokenType.DoubleDot]) {
		while (ps != TokenType.Semicolon) {
			bool isRef = matchIf(ps, TokenType.Ref);
			ir.Type type;
			ir.Token name;
			if (ps == [TokenType.Identifier, TokenType.Comma] || ps == [TokenType.Identifier, TokenType.Semicolon]) {
				if (ps != TokenType.Identifier) {
					return unexpectedToken(ps, f);
				}
				name = ps.get();
				type = buildAutoType(name.location);
			} else {
				auto succeeded = parseType(ps, type);
				if (!succeeded) {
					return parseFailed(ps, f);
				}
				if (ps != TokenType.Identifier) {
					return unexpectedToken(ps, f);
				}
				name = ps.get();
			}
			if (isRef) {
				auto at = new ir.AutoType();
				at.location = type.location;
				at.explicitType = type;
				at.isForeachRef = true;
				type = at;
			}
			f.itervars ~= new ir.Variable();
			f.itervars[$-1].location = type.location;
			f.itervars[$-1].type = type;
			f.itervars[$-1].name = name.value;
			matchIf(ps, TokenType.Comma);
		}
		if (ps != TokenType.Semicolon) {
			return unexpectedToken(ps, f);
		}
		ps.get();
	}

	ir.Exp firstExp;
	auto succeeded = parseExp(ps, firstExp);
	if (!succeeded) {
		return parseFailed(ps, f);
	}
	if (matchIf(ps, ir.TokenType.DoubleDot)) {
		f.beginIntegerRange = firstExp;
		succeeded = parseExp(ps, f.endIntegerRange);
		if (!succeeded) {
			return parseFailed(ps, f);
		}
	} else {
		f.aggregate = firstExp;
	}

	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, f);
	}
	ps.get();
	succeeded = parseBlockStatement(ps, f.block);
	if (!succeeded) {
		return parseFailed(ps, f);
	}
	return Succeeded;
}

ParseStatus parseForStatement(ParserStream ps, out ir.ForStatement f)
{
	f = new ir.ForStatement();
	f.location = ps.peek.location;

	if (ps != TokenType.For) {
		return unexpectedToken(ps, f);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, f);
	}
	ps.get();
	if (ps != TokenType.Semicolon) {
		// for init -- parse declarations or assign expressions.
		auto sink = new NodeSink();
		auto succeeded = parseVariableOrExpression(ps, sink.push);
		if (!succeeded) {
			return parseFailed(ps, f);
		}
		auto first = sink.array;
		if (first[0].nodeType != ir.NodeType.Variable) {
			f.initExps ~= cast(ir.Exp) first[0];
			assert(f.initExps[0] !is null);
			while (ps != TokenType.Semicolon) {
				if (ps != TokenType.Comma) {
					return unexpectedToken(ps, f);
				}
				ps.get();
				ir.Exp e;
				succeeded = parseExp(ps, e);
				if (!succeeded) {
					return parseFailed(ps, f);
				}
				f.initExps ~= e;
			}
			if (ps != TokenType.Semicolon) {
				return unexpectedToken(ps, f);
			}
			ps.get();
		} else {
			foreach (var; first) {
				f.initVars ~= cast(ir.Variable) var;
				assert(f.initVars[$-1] !is null);
			}
		}
	} else {
		if (ps != TokenType.Semicolon) {
			return unexpectedToken(ps, f);
		}
		ps.get();
	}

	if (ps != TokenType.Semicolon) {
		auto succeeded = parseExp(ps, f.test);
		if (!succeeded) {
			return parseFailed(ps, f);
		}
	}
	if (ps != TokenType.Semicolon) {
		return unexpectedToken(ps, f);
	}
	ps.get();

	while (ps != TokenType.CloseParen) {
		ir.Exp e;
		auto succeeded = parseExp(ps, e);
		if (!succeeded) {
			return parseFailed(ps, f);
		}
		f.increments ~= e;
		matchIf(ps, TokenType.Comma);
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, f);
	}
	ps.get();

	auto succeeded = parseBlockStatement(ps, f.block);
	if (!succeeded) {
		return parseFailed(ps, f);
	}

	return Succeeded;
}

ParseStatus parseLabelStatement(ParserStream ps, out ir.LabelStatement ls)
{
	ls = new ir.LabelStatement();
	ls.location = ps.peek.location;

	if (ps != TokenType.Identifier) {
		return unexpectedToken(ps, ls);
	}
	auto nameTok = ps.get();
	ls.label = nameTok.value;
	if (ps != TokenType.Colon) {
		return unexpectedToken(ps, ls);
	}
	ps.get();

	auto sink = new NodeSink();
	auto succeeded = parseStatement(ps, sink.push);
	if (!succeeded) {
		return parseFailed(ps, ls);
	}
	ls.childStatement = sink.array;

	return Succeeded;
}

ParseStatus parseSwitchStatement(ParserStream ps, out ir.SwitchStatement ss)
{
	ss = new ir.SwitchStatement();
	ss.location = ps.peek.location;

	if (matchIf(ps, TokenType.Final)) {
		ss.isFinal = true;
	}

	if (ps != TokenType.Switch) {
		return unexpectedToken(ps, ss);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, ss);
	}
	ps.get();
	auto succeeded = parseExp(ps, ss.condition);
	if (!succeeded) {
		return parseFailed(ps, ss);
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, ss);
	}
	ps.get();

	while (matchIf(ps, TokenType.With)) {
		if (ps != TokenType.OpenParen) {
			return unexpectedToken(ps, ss);
		}
		ps.get();
		ir.Exp e;
		succeeded = parseExp(ps, e);
		if (!succeeded) {
			return parseFailed(ps, ss);
		}
		ss.withs ~= e;
		if (ps != TokenType.CloseParen) {
			return unexpectedToken(ps, ss);
		}
		ps.get();
	}

	if (ps != TokenType.OpenBrace) {
		return unexpectedToken(ps, ss);
	}
	ps.get();

	int braces = 1;  // Everybody gets one.
	while (matchIf(ps, TokenType.With)) {
		if (ps != TokenType.OpenParen) {
			return unexpectedToken(ps, ss);
		}
		ps.get();
		ir.Exp e;
		succeeded = parseExp(ps, e);
		if (!succeeded) {
			return parseFailed(ps, ss);
		}
		ss.withs ~= e;
		if (ps != TokenType.CloseParen) {
			return unexpectedToken(ps, ss);
		}
		ps.get();
		if (matchIf(ps, TokenType.OpenBrace)) {
			braces++;
		}
	}

	static ParseStatus parseCaseStatements(ParserStream ps, out ir.BlockStatement bs)
	{
		bs = new ir.BlockStatement();
		bs.location = ps.peek.location;
		auto sink = new NodeSink();
		while (true) {
			auto type = ps.peek.type;
			if (type == TokenType.Case ||
				type == TokenType.Default ||
				type == TokenType.CloseBrace) {
				break;
			}
			auto succeeded = parseStatement(ps, sink.push);
			if (!succeeded) {
				return succeeded; // Don't report this step.
			}
		}
		bs.statements = sink.array;
		return Succeeded;
	}

	bool hadDefault;
	while (ps != TokenType.CloseBrace) {
		auto newCase = new ir.SwitchCase();
		newCase.location = ps.peek.location;
		switch (ps.peek.type) {
		case TokenType.Default:
			if (ps != TokenType.Default) {
				return unexpectedToken(ps, ss);
			}
			ps.get();
			if (ps != TokenType.Colon) {
				return unexpectedToken(ps, ss);
			}
			ps.get();
			hadDefault = true;
			newCase.isDefault = true;
			succeeded = parseCaseStatements(ps, newCase.statements);
			if (!succeeded) {
				return parseFailed(ps, newCase);
			}
			ss.cases ~= newCase;
			break;
		case TokenType.Case:
			if (ps != TokenType.Case) {
				return unexpectedToken(ps, ss);
			}
			ps.get();
			ir.Exp[] exps;
			ir.Exp e;
			succeeded = parseExp(ps, e);
			if (!succeeded) {
				return parseFailed(ps, ss);
			}
			exps ~= e;
			if (matchIf(ps, TokenType.Comma)) {
				while (ps != TokenType.Colon) {
					succeeded = parseExp(ps, e);
					if (!succeeded) {
						return parseFailed(ps, ss);
					}
					exps ~= e;
					if (ps != TokenType.Colon) {
						if (ps != TokenType.Comma) {
							return unexpectedToken(ps, ss);
						}
						ps.get();
					}
				}
				if (ps != TokenType.Colon) {
					return unexpectedToken(ps, ss);
				}
				ps.get();
				newCase.exps = exps;
			} else {
				newCase.firstExp = exps[0];
				if (ps != TokenType.Colon) {
					return unexpectedToken(ps, ss);
				}
				ps.get();
				if (ps == TokenType.DoubleDot) {
					ps.get();
					if (ps != TokenType.Case) {
						return unexpectedToken(ps, ss);
					}
					ps.get();
					succeeded = parseExp(ps, newCase.secondExp);
					if (!succeeded) {
						return parseFailed(ps, ss);
					}
					if (ps != TokenType.Colon) {
						return unexpectedToken(ps, ss);
					}
					ps.get();
				}
			}
			succeeded = parseCaseStatements(ps, newCase.statements);
			if (!succeeded) {
				return parseFailed(ps, newCase);
			}
			ss.cases ~= newCase;
			break;
		case TokenType.CloseBrace:
			break;
		default:
			return parseExpected(ps, ps.peek.location, ss, "'case', 'default', or '}'");
		}
	}
	while (braces--) {
		if (ps != TokenType.CloseBrace) {
			return unexpectedToken(ps, ss);
		}
		ps.get();
	}

	return Succeeded;
}

ParseStatus parseContinueStatement(ParserStream ps, out ir.ContinueStatement cs)
{
	cs = new ir.ContinueStatement();
	cs.location = ps.peek.location;

	if (ps != TokenType.Continue) {
		return unexpectedToken(ps, cs);
	}
	ps.get();
	if (ps == TokenType.Identifier) {
		auto nameTok = ps.get();
		cs.label = nameTok.value;
	}
	if (ps != TokenType.Semicolon) {
		return unexpectedToken(ps, cs);
	}
	ps.get();

	return Succeeded;
}

ParseStatus parseBreakStatement(ParserStream ps, out ir.BreakStatement bs)
{
	bs = new ir.BreakStatement();
	bs.location = ps.peek.location;

	if (ps != TokenType.Break) {
		return unexpectedToken(ps, bs);
	}
	ps.get();
	if (ps == TokenType.Identifier) {
		auto nameTok = ps.get();
		bs.label = nameTok.value;
	}
	if (ps != TokenType.Semicolon) {
		return unexpectedToken(ps, bs);
	}
	ps.get();

	return Succeeded;
}

ParseStatus parseGotoStatement(ParserStream ps, out ir.GotoStatement gs)
{
	gs = new ir.GotoStatement();
	gs.location = ps.peek.location;

	if (ps != TokenType.Goto) {
		return unexpectedToken(ps, gs);
	}
	ps.get();
	switch (ps.peek.type) {
	case TokenType.Identifier:
		return unsupportedFeature(ps, gs, "goto statement");
	case TokenType.Default:
		if (ps != TokenType.Default) {
			return unexpectedToken(ps, gs);
		}
		ps.get();
		gs.isDefault = true;
		break;
	case TokenType.Case:
		if (ps != TokenType.Case) {
			return unexpectedToken(ps, gs);
		}
		ps.get();
		gs.isCase = true;
		if (ps != TokenType.Semicolon) {
			auto succeeded = parseExp(ps, gs.exp);
			if (!succeeded) {
				return parseFailed(ps, gs);
			}
		}
		break;
	default:
		return parseExpected(ps, ps.peek.location, gs, "identifier, 'case', or 'default'");
	}
	if (ps != TokenType.Semicolon) {
		return unexpectedToken(ps, gs);
	}
	ps.get();

	return Succeeded;
}

ParseStatus parseWithStatement(ParserStream ps, out ir.WithStatement ws)
{
	ws = new ir.WithStatement();
	ws.location = ps.peek.location;

	if (ps != TokenType.With) {
		return unexpectedToken(ps, ws);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, ws);
	}
	ps.get();
	auto succeeded = parseExp(ps, ws.exp);
	if (!succeeded) {
		return parseFailed(ps, ws);
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, ws);
	}
	ps.get();
	succeeded = parseBlockStatement(ps, ws.block);
	if (!succeeded) {
		return parseFailed(ps, ws);
	}

	return Succeeded;
}

ParseStatus parseSynchronizedStatement(ParserStream ps, out ir.SynchronizedStatement ss)
{
	ss = new ir.SynchronizedStatement();
	ss.location = ps.peek.location;

	if (ps != TokenType.Synchronized) {
		return unexpectedToken(ps, ss);
	}
	ps.get();
	if (matchIf(ps, TokenType.OpenParen)) {
		auto succeeded = parseExp(ps, ss.exp);
		if (!succeeded) {
			return parseFailed(ps, ss);
		}
		if (ps != TokenType.CloseParen) {
			return unexpectedToken(ps, ss);
		}
		ps.get();
	}
	auto succeeded = parseBlockStatement(ps, ss.block);
	if (!succeeded) {
		return parseFailed(ps, ss);
	}
	assert(ss.block !is null);

	return Succeeded;
}

ParseStatus parseTryStatement(ParserStream ps, out ir.TryStatement t)
{
	t = new ir.TryStatement();
	t.location = ps.peek.location;

	if (ps != TokenType.Try) {
		return unexpectedToken(ps, t);
	}
	ps.get();
	auto succeeded = parseBlockStatement(ps, t.tryBlock);
	if (!succeeded) {
		return parseFailed(ps, t);
	}

	while (matchIf(ps, TokenType.Catch)) {
		if (matchIf(ps, TokenType.OpenParen)) {
			auto var = new ir.Variable();
			var.location = ps.peek.location;
			succeeded = parseType(ps, var.type);
			if (!succeeded) {
				return parseFailed(ps, t);
			}
			var.specialInitValue = true;
			if (ps != TokenType.CloseParen) {
				if (ps != TokenType.Identifier) {
					return unexpectedToken(ps, t);
				}
				auto nameTok = ps.get();
				var.name = nameTok.value;
			} else {
				var.name = "1__dummy";
			}
			if (ps != TokenType.CloseParen) {
				return unexpectedToken(ps, t);
			}
			ps.get();
			ir.BlockStatement bs;
			succeeded = parseBlockStatement(ps, bs);
			if (!succeeded) {
				return parseFailed(ps, t);
			}
			bs.statements = var ~ bs.statements;
			t.catchVars ~= var;
			t.catchBlocks ~= bs;
		} else {
			succeeded = parseBlockStatement(ps, t.catchAll);
			if (!succeeded) {
				return parseFailed(ps, t);
			}
			if (ps == TokenType.Catch) {
				return parseExpected(ps, ps.peek.location, t, "catch all block as final catch in try statement");
			}
		}
	}

	if (matchIf(ps, TokenType.Finally)) {
		succeeded = parseBlockStatement(ps, t.finallyBlock);
		if (!succeeded) {
			return parseFailed(ps, t);
		}
	}

	if (t.catchBlocks.length == 0 && t.catchAll is null && t.finallyBlock is null) {
		return parseExpected(ps, t.location, t, "catch block");
	}

	return Succeeded;
}

ParseStatus parseThrowStatement(ParserStream ps, out ir.ThrowStatement t)
{
	t = new ir.ThrowStatement();
	t.location = ps.peek.location;
	if (ps != TokenType.Throw) {
		return unexpectedToken(ps, t);
	}
	ps.get();
	auto succeeded = parseExp(ps, t.exp);
	if (!succeeded) {
		return parseFailed(ps, t);
	}
	if (ps != TokenType.Semicolon) {
		return unexpectedToken(ps, t);
	}
	ps.get();
	return Succeeded;
}

ParseStatus parseScopeStatement(ParserStream ps, out ir.ScopeStatement ss)
{
	ss = new ir.ScopeStatement();
	ss.location = ps.peek.location;

	if (ps != TokenType.Scope) {
		return unexpectedToken(ps, ss);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, ss);
	}
	ps.get();
	if (ps != TokenType.Identifier) {
		return unexpectedToken(ps, ss);
	}
	auto nameTok = ps.get();
	switch (nameTok.value) with (ir.ScopeKind) {
	case "exit":
		ss.kind = Exit;
		break;
	case "success":
		ss.kind = Success;
		break;
	case "failure":
		ss.kind = Failure;
		break;
	default:
		return parseExpected(ps, ps.peek.location, ss, "'exit', 'success', or 'failure'");
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, ss);
	}
	ps.get();
	auto succeeded = parseBlockStatement(ps, ss.block);
	if (!succeeded) {
		return parseFailed(ps, ss);
	}

	return Succeeded;
}

ParseStatus parsePragmaStatement(ParserStream ps, out ir.PragmaStatement prs)
{
	prs = new ir.PragmaStatement();
	prs.location = ps.peek.location;

	if (ps != TokenType.Pragma) {
		return unexpectedToken(ps, prs);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, prs);
	}
	ps.get();
	if (ps != TokenType.Identifier) {
		return unexpectedToken(ps, prs);
	}
	auto nameTok = ps.get();
	prs.type = nameTok.value;
	if (matchIf(ps, TokenType.Comma)) {
		auto succeeded = parseArgumentList(ps, prs.arguments);
		if (!succeeded) {
			return parseFailed(ps, prs);
		}
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, prs);
	}
	ps.get();
	auto succeeded = parseBlockStatement(ps, prs.block);
	if (!succeeded) {
		return parseFailed(ps, prs);
	}

	return Succeeded;
}

ParseStatus parseConditionStatement(ParserStream ps, out ir.ConditionStatement cs)
{
	cs = new ir.ConditionStatement();
	cs.location = ps.peek.location;

	auto succeeded = parseCondition(ps, cs.condition);
	if (!succeeded) {
		return parseFailed(ps, cs);
	}
	succeeded = parseBlockStatement(ps, cs.block);
	if (!succeeded) {
		return parseFailed(ps, cs);
	}
	if (matchIf(ps, TokenType.Else)) {
		succeeded = parseBlockStatement(ps, cs._else);
		if (!succeeded) {
			return parseFailed(ps, cs);
		}
	}

	return Succeeded;
}

ParseStatus parseMixinStatement(ParserStream ps, out ir.MixinStatement ms)
{
	ms = new ir.MixinStatement();
	ms.location = ps.peek.location;
	if (ps != TokenType.Mixin) {
		return unexpectedToken(ps, ms);
	}
	ps.get();
	
	if (matchIf(ps, TokenType.OpenParen)) {
		auto succeeded = parseExp(ps, ms.stringExp);
		if (!succeeded) {
			return parseFailed(ps, ms);
		}
		if (ps != TokenType.CloseParen) {
			return unexpectedToken(ps, ms);
		}
		ps.get();
	} else {
		if (ps != TokenType.Identifier) {
			return unexpectedToken(ps, ms);
		}
		auto ident = ps.get();

		auto qualifiedName = new ir.QualifiedName();
		qualifiedName.identifiers ~= new ir.Identifier(ident.value);

		ms.id = qualifiedName;

		if (ps != TokenType.Bang) {
			return unexpectedToken(ps, ms);
		}
		ps.get();
		// TODO allow arguments
		if (ps != TokenType.OpenParen) {
			return unexpectedToken(ps, ms);
		}
		ps.get();
		if (ps != TokenType.CloseParen) {
			return unexpectedToken(ps, ms);
		}
		ps.get();
	}
	if (ps != TokenType.Semicolon) {
		return unexpectedToken(ps, ms);
	}
	ps.get();

	return Succeeded;
}

ParseStatus parseStaticIs(ParserStream ps, out ir.AssertStatement as)
{
	ps.get();
	ir.IsExp isExp;
	ps.saveTokens();
	auto succeeded = parseIsExp(ps, isExp);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.IsExp);
	}
	Token[] tokens = ps.doneSavingTokens();
	as = new ir.AssertStatement();
	as.location = isExp.location;
	as.isStatic = true;
	as.condition = isExp;
	string msg = "";
	foreach (token; tokens) {
		msg ~= token.value;
		auto c = token.value.length == 0 ? ' ' : token.value[0];
		switch (c) {
		case '[', ']', '(', ')', '{', '}':
			break;
		default:
			msg ~= " ";
			break;
		}
	}
	as.message = buildConstantString(isExp.location, msg);
	return Succeeded;
}

// a := 1
ParseStatus parseColonAssign(ParserStream ps, NodeSinkDg dg)
{
	ir.Variable var;
	auto loc = ps.peek.location;

	Token[] idents;
	while (ps != TokenType.Colon && ps != TokenType.ColonAssign) {
		if (ps != TokenType.Identifier) {
			return unexpectedToken(ps, ir.NodeType.Variable);
		}
		idents ~= ps.get();
		if (matchIf(ps, TokenType.Comma)) {
			if (ps != TokenType.Identifier) {
				return unexpectedToken(ps, ir.NodeType.Variable);
			}
		}
	}
	if (idents.length > 1 || ps == TokenType.Colon) {
		return parseColonDeclaration(ps, idents, dg);
	}
	if (ps != TokenType.ColonAssign) {
		return unexpectedToken(ps, ir.NodeType.Variable);
	}
	ps.get();

	ir.Exp exp;
	auto succeeded = parseExp(ps, exp);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Variable);
	}
	succeeded = match(ps, ir.NodeType.Variable, TokenType.Semicolon);
	if (!succeeded) {
		return succeeded;
	}
	var = buildVariable(loc, buildAutoType(loc), ir.Variable.Storage.Invalid,
                        idents[0].value, exp);
	dg(var);
	return Succeeded;
}

// a, b : int
ParseStatus parseColonDeclaration(ParserStream ps, Token[] idents, NodeSinkDg dg)
{
	if (ps != TokenType.Colon) {
		return unexpectedToken(ps, ir.NodeType.Variable);
	}
	ps.get();
	ir.Type type;
	auto succeeded = parseType(ps, type);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Variable);
	}
	ir.Exp assign;
	if (matchIf(ps, TokenType.Assign)) {
		if (idents.length > 1) {
			return unexpectedToken(ps, ir.NodeType.Variable);
		}
		succeeded = parseExp(ps, assign);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Variable);
		}
	}
	foreach (i, ident; idents) {
		auto var = buildVariable(ident.location, i > 0 ? copyType(type) : type,
		                         ir.Variable.Storage.Invalid, ident.value);
		var.assign = assign;
		dg(var);
	}
	return match(ps, ir.NodeType.Variable, ir.TokenType.Semicolon);
}
