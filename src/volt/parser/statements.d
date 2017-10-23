/*#D*/
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.statements;

import watt.text.ascii;
import watt.text.sink;

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


ParseStatus parseStatement(ParserStream ps, NodeSinkDg dgt)
{
	auto succeeded = eatComments(ps);

	switch (ps.peek.type) {
	case TokenType.Semicolon:
		// Just ignore EmptyStatements
		return match(ps, ir.NodeType.Invalid, TokenType.Semicolon);
	case TokenType.Import:
		ir.Import _import;
		succeeded = parseImport(ps, /*#out*/_import);
		if (!succeeded) {
			return succeeded;
		}
		dgt(_import);
		return eatComments(ps);
	case TokenType.Return:
		ir.ReturnStatement r;
		succeeded = parseReturnStatement(ps, /*#out*/r);
		if (!succeeded) {
			return succeeded;
		}
		dgt(r);
		return eatComments(ps);
	case TokenType.OpenBrace:
		ir.BlockStatement b;
		succeeded = parseBlockStatement(ps, /*#out*/b);
		if (!succeeded) {
			return succeeded;
		}
		dgt(b);
		return eatComments(ps);
	case TokenType.Asm:
		ir.AsmStatement a;
		succeeded = parseAsmStatement(ps, /*#out*/a);
		if (!succeeded) {
			return succeeded;
		}
		dgt(a);
		return eatComments(ps);
	case TokenType.If:
		ir.IfStatement i;
		succeeded = parseIfStatement(ps, /*#out*/i);
		if (!succeeded) {
			return succeeded;
		}
		dgt(i);
		return eatComments(ps);
	case TokenType.While:
		ir.WhileStatement w;
		succeeded = parseWhileStatement(ps, /*#out*/w);
		if (!succeeded) {
			return succeeded;
		}
		dgt(w);
		return eatComments(ps);
	case TokenType.Do:
		ir.DoStatement d;
		succeeded = parseDoStatement(ps, /*#out*/d);
		if (!succeeded) {
			return succeeded;
		}
		dgt(d);
		return eatComments(ps);
	case TokenType.For:
		ir.ForStatement f;
		succeeded = parseForStatement(ps, /*#out*/f);
		if (!succeeded) {
			return succeeded;
		}
		dgt(f);
		return eatComments(ps);
	case TokenType.Foreach, TokenType.ForeachReverse:
		ir.ForeachStatement f;
		succeeded = parseForeachStatement(ps, /*#out*/f);
		if (!succeeded) {
			return succeeded;
		}
		dgt(f);
		return eatComments(ps);
	case TokenType.Switch:
		ir.SwitchStatement ss;
		succeeded = parseSwitchStatement(ps, /*#out*/ss);
		if (!succeeded) {
			return succeeded;
		}
		dgt(ss);
		return eatComments(ps);
	case TokenType.Break:
		ir.BreakStatement bs;
		succeeded = parseBreakStatement(ps, /*#out*/bs);
		if (!succeeded) {
			return succeeded;
		}
		dgt(bs);
		return eatComments(ps);
	case TokenType.Continue:
		ir.ContinueStatement cs;
		succeeded = parseContinueStatement(ps, /*#out*/cs);
		if (!succeeded) {
			return succeeded;
		}
		dgt(cs);
		return eatComments(ps);
	case TokenType.Goto:
		ir.GotoStatement gs;
		succeeded = parseGotoStatement(ps, /*#out*/gs);
		if (!succeeded) {
			return succeeded;
		}
		dgt(gs);
		return eatComments(ps);
	case TokenType.With:
		ir.WithStatement ws;
		succeeded = parseWithStatement(ps, /*#out*/ws);
		if (!succeeded) {
			return succeeded;
		}
		dgt(ws);
		return eatComments(ps);
	case TokenType.Synchronized:
		ir.SynchronizedStatement ss;
		succeeded = parseSynchronizedStatement(ps, /*#out*/ss);
		if (!succeeded) {
			return succeeded;
		}
		dgt(ss);
		return eatComments(ps);
	case TokenType.Try:
		ir.TryStatement t;
		succeeded = parseTryStatement(ps, /*#out*/t);
		if (!succeeded) {
			return succeeded;
		}
		dgt(t);
		return eatComments(ps);
	case TokenType.Throw:
		ir.ThrowStatement t;
		succeeded = parseThrowStatement(ps, /*#out*/t);
		if (!succeeded) {
			return succeeded;
		}
		dgt(t);
		return eatComments(ps);
	case TokenType.Scope:
		if (ps.lookahead(1).type == TokenType.OpenParen && ps.lookahead(2).type == TokenType.Identifier &&
			ps.lookahead(3).type == TokenType.CloseParen) {
			auto identTok = ps.lookahead(2);
			if (identTok.value == "exit" || identTok.value == "failure" || identTok.value == "success") {
				ir.ScopeStatement ss;
				succeeded = parseScopeStatement(ps, /*#out*/ss);
				if (!succeeded) {
					return succeeded;
				}
				dgt(ss);
				return eatComments(ps);
			}
		}
		goto default;
	case TokenType.Pragma:
		ir.PragmaStatement prs;
		succeeded = parsePragmaStatement(ps, /*#out*/prs);
		if (!succeeded) {
			return succeeded;
		}
		dgt(prs);
		return eatComments(ps);
	case TokenType.Identifier:
		if (ps.lookahead(1).type == TokenType.Colon ||
		    ps.lookahead(1).type == TokenType.ColonAssign ||
			ps.lookahead(1).type == TokenType.Comma) {
			succeeded = parseColonAssign(ps, /*#out*/dgt);
			if (!succeeded) {
				return succeeded;
			}
			return eatComments(ps);
		} else {
			goto default;
		}
	case TokenType.Final:
		if (ps.lookahead(1).type == TokenType.Switch) {
			goto case TokenType.Switch;
		} else {
			goto default;
		}
	case TokenType.Static:
		if (ps.lookahead(1).type == TokenType.If) {
			goto case TokenType.Version;
		} else if (ps.lookahead(1).type == TokenType.Assert) {
			goto case TokenType.Assert;
		} else if (ps.lookahead(1).type == TokenType.Is) {
			ir.AssertStatement as;
			succeeded = parseStaticIs(ps, /*#out*/as);
			if (!succeeded) {
				return succeeded;
			}
			dgt(as);
			return eatComments(ps);
		} else {
			goto default;
		}
	case TokenType.Assert:
		ir.AssertStatement a;
		succeeded = parseAssertStatement(ps, /*#out*/a);
		if (!succeeded) {
			return succeeded;
		}
		dgt(a);
		return eatComments(ps);
	case TokenType.Version:
	case TokenType.Debug:
		ir.ConditionStatement cs;
		succeeded = parseConditionStatement(ps, /*#out*/cs);
		if (!succeeded) {
			return succeeded;
		}
		dgt(cs);
		return eatComments(ps);
	case TokenType.Mixin:
		ir.MixinStatement ms;
		succeeded = parseMixinStatement(ps, /*#out*/ms);
		if (!succeeded) {
			return succeeded;
		}
		dgt(ms);
		return eatComments(ps);
	default:
		// It is safe to just set succeeded like this since
		// only variable returns more then one node.
		void func(ir.Node n) {
			auto exp = cast(ir.Exp)n;
			if (exp is null) {
				dgt(n);
				return;
			}

			succeeded = match(ps, ir.NodeType.ExpStatement, TokenType.Semicolon);
			if (!succeeded) {
				return;
			}

			auto es = new ir.ExpStatement();
			es.loc = exp.loc;
			es.exp = exp;
			dgt(es);
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
}

/* Try to parse as a declaration first because
 *   Object* a;
 * Is always a declaration. If you do something like
 *   int a, b;
 *   a * b;
 * An error like "a used as type" should be emitted.
 */
ParseStatus parseVariableOrExpression(ParserStream ps, NodeSinkDg dgt)
{
	size_t pos = ps.save();
	auto succeeded = parseVariable(ps, dgt);
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
	succeeded = parseType(ps, /*#out*/base);
	if (succeeded) {
		succeeded = parseFunction(ps, /*#out*/func, base);
		if (succeeded) {
			dgt(func);
			return Succeeded;
		}
	}

	if (ps.neverIgnoreError) {
		return Failed;
	}

	ps.restore(pos);
	ps.resetErrors();

	ir.Exp e;
	succeeded = parseExp(ps, /*#out*/e);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Variable);
	}
	dgt(e);
	return Succeeded;
}

ParseStatus parseAssertStatement(ParserStream ps, out ir.AssertStatement as)
{
	as = new ir.AssertStatement();
	as.loc = ps.peek.loc;
	as.isStatic = matchIf(ps, TokenType.Static);
	if (ps != TokenType.Assert) {
		return unexpectedToken(ps, as);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, as);
	}
	ps.get();
	auto succeeded = parseExp(ps, /*#out*/as.condition);
	if (!succeeded) {
		return parseFailed(ps, as);
	}
	if (matchIf(ps, TokenType.Comma)) {
		succeeded = parseExp(ps, /*#out*/as.message);
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
	e.loc = ps.peek.loc;

	auto succeeded = parseExp(ps, /*#out*/e.exp);
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
	r.loc = ps.peek.loc;

	if (ps != TokenType.Return) {
		return unexpectedToken(ps, r);
	}
	ps.get();

	// return;
	if (matchIf(ps, TokenType.Semicolon)) {
		return Succeeded;
	}

	auto succeeded = parseExp(ps, /*#out*/r.exp);
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
	bs.loc = ps.peek.loc;

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
	as.loc = ps.peek.loc;

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
	i.loc = ps.peek.loc;

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
	if (ps == [TokenType.Identifier, TokenType.ColonAssign]) {
		i.autoName = ps.peek.value;
		match(ps, i, TokenType.Identifier);
		match(ps, i, TokenType.ColonAssign);
	}
	auto succeeded = parseExp(ps, /*#out*/i.exp);
	if (!succeeded) {
		return parseFailed(ps, i);
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, i);
	}
	ps.get();
	succeeded = parseBlockStatement(ps, /*#out*/i.thenState);
	if (!succeeded) {
		return parseFailed(ps, i);
	}
	if (matchIf(ps, TokenType.Else)) {
		succeeded = parseBlockStatement(ps, /*#out*/i.elseState);
		if (!succeeded) {
			return parseFailed(ps, i);
		}
	}

	return Succeeded;
}

ParseStatus parseWhileStatement(ParserStream ps, out ir.WhileStatement w)
{
	w = new ir.WhileStatement();
	w.loc = ps.peek.loc;

	if (ps != TokenType.While) {
		return unexpectedToken(ps, w);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, w);
	}
	ps.get();
	auto succeeded = parseExp(ps, /*#out*/w.condition);
	if (!succeeded) {
		return parseFailed(ps, w);
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, w);
	}
	ps.get();
	succeeded = parseBlockStatement(ps, /*#out*/w.block);
	if (!succeeded) {
		return parseFailed(ps, w);
	}

	return Succeeded;
}

ParseStatus parseDoStatement(ParserStream ps, out ir.DoStatement d)
{
	d = new ir.DoStatement();
	d.loc = ps.peek.loc;

	if (ps != TokenType.Do) {
		return unexpectedToken(ps, d);
	}
	ps.get();
	auto succeeded = parseBlockStatement(ps, /*#out*/d.block);
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
	succeeded = parseExp(ps, /*#out*/d.condition);
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
	f.loc = ps.peek.loc;

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
				type = buildAutoType(/*#ref*/name.loc);
			} else if (ps == [TokenType.Identifier, TokenType.Colon]) {
				name = ps.get();
				auto succeeded = match(ps, f, TokenType.Colon);
				if (!succeeded) {
					return parseFailed(ps, f);
				}
				succeeded = parseType(ps, /*#out*/type);
				if (!succeeded) {
					return parseFailed(ps, f);
				}
			} else {
				auto succeeded = parseType(ps, /*#out*/type);
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
				at.loc = type.loc;
				at.explicitType = type;
				at.isForeachRef = true;
				type = at;
			}
			f.itervars ~= new ir.Variable();
			f.itervars[$-1].loc = type.loc;
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
	auto succeeded = parseExp(ps, /*#out*/firstExp);
	if (!succeeded) {
		return parseFailed(ps, f);
	}
	if (matchIf(ps, ir.TokenType.DoubleDot)) {
		f.beginIntegerRange = firstExp;
		succeeded = parseExp(ps, /*#out*/f.endIntegerRange);
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
	succeeded = parseBlockStatement(ps, /*#out*/f.block);
	if (!succeeded) {
		return parseFailed(ps, f);
	}
	return Succeeded;
}

ParseStatus parseForStatement(ParserStream ps, out ir.ForStatement f)
{
	f = new ir.ForStatement();
	f.loc = ps.peek.loc;

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
				succeeded = parseExp(ps, /*#out*/e);
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
				if (f.initVars[$-1] is null) {
					return unexpectedToken(ps, f);
				}
			}
		}
	} else {
		if (ps != TokenType.Semicolon) {
			return unexpectedToken(ps, f);
		}
		ps.get();
	}

	if (ps != TokenType.Semicolon) {
		auto succeeded = parseExp(ps, /*#out*/f.test);
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
		auto succeeded = parseExp(ps, /*#out*/e);
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

	auto succeeded = parseBlockStatement(ps, /*#out*/f.block);
	if (!succeeded) {
		return parseFailed(ps, f);
	}

	return Succeeded;
}

ParseStatus parseLabelStatement(ParserStream ps, out ir.LabelStatement ls)
{
	ls = new ir.LabelStatement();
	ls.loc = ps.peek.loc;

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
	ss.loc = ps.peek.loc;

	if (matchIf(ps, TokenType.Final)) {
		ss.isFinal = true;
	}

	if (ps != TokenType.Switch) {
		return wrongToken(ps, ss.nodeType, ps.peek, TokenType.Switch);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return wrongToken(ps, ss.nodeType, ps.peek, TokenType.OpenParen);
	}
	ps.get();
	auto succeeded = parseExp(ps, /*#out*/ss.condition);
	if (!succeeded) {
		return parseFailed(ps, ss);
	}
	if (ps != TokenType.CloseParen) {
		return wrongToken(ps, ss.nodeType, ps.peek, TokenType.CloseParen);
	}
	ps.get();

	while (matchIf(ps, TokenType.With)) {
		if (ps != TokenType.OpenParen) {
			return wrongToken(ps, ss.nodeType, ps.peek, TokenType.OpenParen);
		}
		ps.get();
		ir.Exp e;
		succeeded = parseExp(ps, /*#out*/e);
		if (!succeeded) {
			return parseFailed(ps, ss);
		}
		ss.withs ~= e;
		if (ps != TokenType.CloseParen) {
			return wrongToken(ps, ss.nodeType, ps.peek, TokenType.CloseParen);
		}
		ps.get();
	}

	if (ps != TokenType.OpenBrace) {
		return wrongToken(ps, ss.nodeType, ps.peek, TokenType.OpenBrace);
	}
	ps.get();

	int braces = 1;
	while (matchIf(ps, TokenType.With)) {
		if (ps != TokenType.OpenParen) {
			return wrongToken(ps, ss.nodeType, ps.peek, TokenType.OpenParen);
		}
		ps.get();
		ir.Exp e;
		succeeded = parseExp(ps, /*#out*/e);
		if (!succeeded) {
			return parseFailed(ps, ss);
		}
		ss.withs ~= e;
		if (ps != TokenType.CloseParen) {
			return wrongToken(ps, ss.nodeType, ps.peek, TokenType.CloseParen);
		}
		ps.get();
		if (matchIf(ps, TokenType.OpenBrace)) {
			braces++;
		}
	}

	static ParseStatus parseCaseStatements(ParserStream ps, out ir.BlockStatement bs)
	{
		bs = new ir.BlockStatement();
		bs.loc = ps.peek.loc;
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
		newCase.loc = ps.peek.loc;
		switch (ps.peek.type) {
		case TokenType.Default:
			if (ps != TokenType.Default) {
				return wrongToken(ps, ss.nodeType, ps.peek, TokenType.Default);
			}
			ps.get();
			if (ps != TokenType.Colon) {
				return wrongToken(ps, ss.nodeType, ps.peek, TokenType.Colon);
			}
			ps.get();
			hadDefault = true;
			newCase.isDefault = true;
			succeeded = parseCaseStatements(ps, /*#out*/newCase.statements);
			if (!succeeded) {
				return parseFailed(ps, newCase);
			}
			ss.cases ~= newCase;
			break;
		case TokenType.Case:
			if (ps != TokenType.Case) {
				return wrongToken(ps, ss.nodeType, ps.peek, TokenType.Case);
			}
			ps.get();
			ir.Exp[] exps;
			ir.Exp e;
			succeeded = parseExp(ps, /*#out*/e);
			if (!succeeded) {
				return parseFailed(ps, ss);
			}
			exps ~= e;
			if (matchIf(ps, TokenType.Comma)) {
				while (ps != TokenType.Colon) {
					succeeded = parseExp(ps, /*#out*/e);
					if (!succeeded) {
						return parseFailed(ps, ss);
					}
					exps ~= e;
					if (ps != TokenType.Colon) {
						if (ps != TokenType.Comma) {
							return wrongToken(ps, ss.nodeType, ps.peek, TokenType.Comma);
						}
						ps.get();
					}
				}
				if (ps != TokenType.Colon) {
					return wrongToken(ps, ss.nodeType, ps.peek, TokenType.Colon);
				}
				ps.get();
				newCase.exps = exps;
			} else {
				newCase.firstExp = exps[0];
				if (ps != TokenType.Colon) {
					return wrongToken(ps, ss.nodeType, ps.peek, TokenType.Colon);
				}
				ps.get();
				if (ps == TokenType.DoubleDot) {
					ps.get();
					if (ps != TokenType.Case) {
						return wrongToken(ps, ss.nodeType, ps.peek, TokenType.Case);
					}
					ps.get();
					succeeded = parseExp(ps, /*#out*/newCase.secondExp);
					if (!succeeded) {
						return parseFailed(ps, ss);
					}
					if (ps != TokenType.Colon) {
						return wrongToken(ps, ss.nodeType, ps.peek, TokenType.Colon);
					}
					ps.get();
				}
			}
			succeeded = parseCaseStatements(ps, /*#out*/newCase.statements);
			if (!succeeded) {
				return parseFailed(ps, newCase);
			}
			ss.cases ~= newCase;
			break;
		case TokenType.CloseBrace:
			break;
		default:
			return parseExpected(ps, ps.peek.loc, ss, "'case', 'default', or '}'");
		}
	}
	while (braces--) {
		if (ps != TokenType.CloseBrace) {
			return wrongToken(ps, ss.nodeType, ps.peek, TokenType.CloseBrace);
		}
		ps.get();
	}

	return Succeeded;
}

ParseStatus parseContinueStatement(ParserStream ps, out ir.ContinueStatement cs)
{
	cs = new ir.ContinueStatement();
	cs.loc = ps.peek.loc;

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
	bs.loc = ps.peek.loc;

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
	gs.loc = ps.peek.loc;

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
			auto succeeded = parseExp(ps, /*#out*/gs.exp);
			if (!succeeded) {
				return parseFailed(ps, gs);
			}
		}
		break;
	default:
		return parseExpected(ps, ps.peek.loc, gs, "identifier, 'case', or 'default'");
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
	ws.loc = ps.peek.loc;

	if (ps != TokenType.With) {
		return unexpectedToken(ps, ws);
	}
	ps.get();
	if (ps != TokenType.OpenParen) {
		return unexpectedToken(ps, ws);
	}
	ps.get();
	auto succeeded = parseExp(ps, /*#out*/ws.exp);
	if (!succeeded) {
		return parseFailed(ps, ws);
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, ws);
	}
	ps.get();
	succeeded = parseBlockStatement(ps, /*#out*/ws.block);
	if (!succeeded) {
		return parseFailed(ps, ws);
	}

	return Succeeded;
}

ParseStatus parseSynchronizedStatement(ParserStream ps, out ir.SynchronizedStatement ss)
{
	ss = new ir.SynchronizedStatement();
	ss.loc = ps.peek.loc;

	if (ps != TokenType.Synchronized) {
		return unexpectedToken(ps, ss);
	}
	ps.get();
	if (matchIf(ps, TokenType.OpenParen)) {
		auto succeeded = parseExp(ps, /*#out*/ss.exp);
		if (!succeeded) {
			return parseFailed(ps, ss);
		}
		if (ps != TokenType.CloseParen) {
			return unexpectedToken(ps, ss);
		}
		ps.get();
	}
	auto succeeded = parseBlockStatement(ps, /*#out*/ss.block);
	if (!succeeded) {
		return parseFailed(ps, ss);
	}
	assert(ss.block !is null);

	return Succeeded;
}

ParseStatus parseTryStatement(ParserStream ps, out ir.TryStatement t)
{
	t = new ir.TryStatement();
	t.loc = ps.peek.loc;

	if (ps != TokenType.Try) {
		return unexpectedToken(ps, t);
	}
	ps.get();
	auto succeeded = parseBlockStatement(ps, /*#out*/t.tryBlock);
	if (!succeeded) {
		return parseFailed(ps, t);
	}

	while (matchIf(ps, TokenType.Catch)) {
		if (matchIf(ps, TokenType.OpenParen)) {
			auto var = new ir.Variable();
			var.loc = ps.peek.loc;
			var.specialInitValue = true;
			if (isColonDeclaration(ps)) {
				// catch (e: Exception)
				if (ps != TokenType.Identifier) {
					return unexpectedToken(ps, t);
				}
				var.name = ps.get().value;
				succeeded = match(ps, t, TokenType.Colon);
				if (!succeeded) {
					return succeeded;
				}
				succeeded = parseType(ps, /*#out*/var.type);
				if (!succeeded) {
					return parseFailed(ps, t);
				}
			} else {
				// catch (Exception e) or catch (Exception)
				succeeded = parseType(ps, /*#out*/var.type);
				if (!succeeded) {
					return parseFailed(ps, t);
				}
				if (ps != TokenType.CloseParen) {
					if (ps != TokenType.Identifier) {
						return unexpectedToken(ps, t);
					}
					auto nameTok = ps.get();
					var.name = nameTok.value;
				} else {
					var.name = "1__dummy";
				}
			}
			if (ps != TokenType.CloseParen) {
				return unexpectedToken(ps, t);
			}
			ps.get();
			ir.BlockStatement bs;
			succeeded = parseBlockStatement(ps, /*#out*/bs);
			if (!succeeded) {
				return parseFailed(ps, t);
			}
			bs.statements = var ~ bs.statements;
			t.catchVars ~= var;
			t.catchBlocks ~= bs;
		} else {
			succeeded = parseBlockStatement(ps, /*#out*/t.catchAll);
			if (!succeeded) {
				return parseFailed(ps, t);
			}
			if (ps == TokenType.Catch) {
				return parseExpected(ps, ps.peek.loc, t, "catch all block as final catch in try statement");
			}
		}
	}

	if (matchIf(ps, TokenType.Finally)) {
		succeeded = parseBlockStatement(ps, /*#out*/t.finallyBlock);
		if (!succeeded) {
			return parseFailed(ps, t);
		}
	}

	if (t.catchBlocks.length == 0 && t.catchAll is null && t.finallyBlock is null) {
		return parseExpected(ps, t.loc, t, "catch block");
	}

	return Succeeded;
}

ParseStatus parseThrowStatement(ParserStream ps, out ir.ThrowStatement t)
{
	t = new ir.ThrowStatement();
	t.loc = ps.peek.loc;
	if (ps != TokenType.Throw) {
		return unexpectedToken(ps, t);
	}
	ps.get();
	auto succeeded = parseExp(ps, /*#out*/t.exp);
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
	ss.loc = ps.peek.loc;

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
		return parseExpected(ps, ps.peek.loc, ss, "'exit', 'success', or 'failure'");
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, ss);
	}
	ps.get();
	auto succeeded = parseBlockStatement(ps, /*#out*/ss.block);
	if (!succeeded) {
		return parseFailed(ps, ss);
	}

	return Succeeded;
}

ParseStatus parsePragmaStatement(ParserStream ps, out ir.PragmaStatement prs)
{
	prs = new ir.PragmaStatement();
	prs.loc = ps.peek.loc;

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
		auto succeeded = parseArgumentList(ps, /*#out*/prs.arguments);
		if (!succeeded) {
			return parseFailed(ps, prs);
		}
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, prs);
	}
	ps.get();
	auto succeeded = parseBlockStatement(ps, /*#out*/prs.block);
	if (!succeeded) {
		return parseFailed(ps, prs);
	}

	return Succeeded;
}

ParseStatus parseConditionStatement(ParserStream ps, out ir.ConditionStatement cs)
{
	cs = new ir.ConditionStatement();
	cs.loc = ps.peek.loc;

	auto succeeded = parseCondition(ps, /*#out*/cs.condition);
	if (!succeeded) {
		return parseFailed(ps, cs);
	}
	succeeded = parseBlockStatement(ps, /*#out*/cs.block);
	if (!succeeded) {
		return parseFailed(ps, cs);
	}
	if (matchIf(ps, TokenType.Else)) {
		succeeded = parseBlockStatement(ps, /*#out*/cs._else);
		if (!succeeded) {
			return parseFailed(ps, cs);
		}
	}

	return Succeeded;
}

ParseStatus parseMixinStatement(ParserStream ps, out ir.MixinStatement ms)
{
	ms = new ir.MixinStatement();
	ms.loc = ps.peek.loc;
	if (ps != TokenType.Mixin) {
		return unexpectedToken(ps, ms);
	}
	ps.get();
	
	if (matchIf(ps, TokenType.OpenParen)) {
		auto succeeded = parseExp(ps, /*#out*/ms.stringExp);
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
	auto succeeded = parseIsExp(ps, /*#out*/isExp);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.IsExp);
	}
	Token[] tokens = ps.doneSavingTokens();
	as = new ir.AssertStatement();
	as.loc = isExp.loc;
	as.isStatic = true;
	as.condition = isExp;
	StringSink msg;
	foreach (token; tokens) {
		msg.sink(token.value);
		auto c = token.value.length == 0 ? ' ' : token.value[0];
		switch (c) {
		case '[', ']', '(', ')', '{', '}':
			break;
		default:
			msg.sink(" ");
			break;
		}
	}
	as.message = buildConstantString(/*#ref*/isExp.loc, msg.toString());
	return Succeeded;
}

// a := 1
ParseStatus parseColonAssign(ParserStream ps, NodeSinkDg dgt)
{
	ir.Variable var;
	auto loc = ps.peek.loc;

	auto comment = ps.comment();

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
		return parseColonDeclaration(ps, /*#out*/comment, idents, dgt);
	}
	if (ps != TokenType.ColonAssign) {
		return unexpectedToken(ps, ir.NodeType.Variable);
	}
	ps.get();

	ir.Exp exp;
	auto succeeded = parseExp(ps, /*#out*/exp);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Variable);
	}
	succeeded = match(ps, ir.NodeType.Variable, TokenType.Semicolon);
	if (!succeeded) {
		return succeeded;
	}
	var = buildVariable(/*#ref*/loc, buildAutoType(/*#ref*/loc), ir.Variable.Storage.Invalid,
                        idents[0].value, exp);
	var.docComment = comment;
	ps.retroComment = var;
	dgt(var);
	return Succeeded;
}

// a, b : int
ParseStatus parseColonDeclaration(ParserStream ps, string comment, Token[] idents, NodeSinkDg dgt)
{
	if (ps != TokenType.Colon) {
		return unexpectedToken(ps, ir.NodeType.Variable);
	}
	ps.get();
	ir.Type type;
	auto succeeded = parseType(ps, /*#out*/type);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Variable);
	}
	ir.Exp assign;
	if (matchIf(ps, TokenType.Assign)) {
		if (idents.length > 1) {
			return unexpectedToken(ps, ir.NodeType.Variable);
		}
		succeeded = parseExp(ps, /*#out*/assign);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Variable);
		}
	}
	foreach (i, ident; idents) {
		auto var = buildVariable(/*#ref*/ident.loc, i > 0 ? copyType(type) : type,
		                         ir.Variable.Storage.Invalid, ident.value);
		var.assign = assign;
		var.docComment = comment;
		ps.retroComment = var;
		dgt(var);
	}
	return match(ps, ir.NodeType.Variable, ir.TokenType.Semicolon);
}
