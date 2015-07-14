// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.statements;

import ir = volt.ir.ir;

import volt.errors;
import volt.exceptions;
import volt.token.stream;

import volt.parser.base;
import volt.parser.declaration;
import volt.parser.expression;
import volt.parser.toplevel;


ir.Node[] parseStatement(ParserStream ps)
{
	eatComments(ps);
	scope (exit) eatComments(ps);
	switch (ps.peek.type) {
	case TokenType.Semicolon:
		match(ps, TokenType.Semicolon);
		// Just ignore EmptyStatements
		return [];
	case TokenType.Return:
		return [parseReturnStatement(ps)];
	case TokenType.OpenBrace:
		return [parseBlockStatement(ps)];
	case TokenType.Asm:
		return [parseAsmStatement(ps)];
	case TokenType.If:
		return [parseIfStatement(ps)];
	case TokenType.While:
		return [parseWhileStatement(ps)];
	case TokenType.Do:
		return [parseDoStatement(ps)];
	case TokenType.For:
		return [parseForStatement(ps)];
	case TokenType.Foreach, TokenType.ForeachReverse:
		return [parseForeachStatement(ps)];
	case TokenType.Switch:
		return [parseSwitchStatement(ps)];
	case TokenType.Break:
		return [parseBreakStatement(ps)];
	case TokenType.Continue:
		return [parseContinueStatement(ps)];
	case TokenType.Goto:
		return [parseGotoStatement(ps)];
	case TokenType.With:
		return [parseWithStatement(ps)];
	case TokenType.Synchronized:
		return [parseSynchronizedStatement(ps)];
	case TokenType.Try:
		return [parseTryStatement(ps)];
	case TokenType.Throw:
		return [parseThrowStatement(ps)];
	case TokenType.Scope:
		if (ps.lookahead(1).type == TokenType.OpenParen && ps.lookahead(2).type == TokenType.Identifier &&
			ps.lookahead(3).type == TokenType.CloseParen) {
			auto identTok = ps.lookahead(2);
			if (identTok.value == "exit" || identTok.value == "failure" || identTok.value == "success") {
				return [parseScopeStatement(ps)];
			}
		}
		goto default;
	case TokenType.Pragma:
		return [parsePragmaStatement(ps)];
	case TokenType.Identifier:
		if (ps.lookahead(1).type == TokenType.Colon) {
			return [parseLabelStatement(ps)];
		} else {
			goto default;
		}
		version(Volt) assert(false);
	case TokenType.Final:
		if (ps.lookahead(1).type == TokenType.Switch) {
			goto case TokenType.Switch;
		} else {
			goto default;
		}
		version(Volt) assert(false);
	case TokenType.Static:
		if (ps.lookahead(1).type == TokenType.If) {
			goto case TokenType.Version;
		} else if (ps.lookahead(1).type == TokenType.Assert) {
			goto case TokenType.Assert;
		} else {
			goto default;
		}
		version(Volt) assert(false);
	case TokenType.Assert:
		return [parseAssertStatement(ps)];
	case TokenType.Version:
	case TokenType.Debug:
		return [parseConditionStatement(ps)];
	case TokenType.Mixin:
		return [parseMixinStatement(ps)];
	default:
		ir.Node[] node = parseVariableOrExpression(ps);
		if (node[0].nodeType != ir.NodeType.Variable && node[0].nodeType != ir.NodeType.Function) {
			// create an ExpStatement out of an Expression
			match(ps, TokenType.Semicolon);
			auto es = new ir.ExpStatement();
			es.location = node[0].location;
			auto asExp = cast(ir.Exp) node[0];
			assert(asExp !is null);
			es.exp = asExp;
			return [es];

		} else {
			// return a regular declaration
			return node;
		}
	}
	version(Volt) assert(false);
}

/* Try to parse as a declaration first because
 *   Object* a;
 * Is always a declaration. If you do something like
 *   int a, b;
 *   a * b;
 * An error like "a used as type" should be emitted.
 */
ir.Node[] parseVariableOrExpression(ParserStream ps)
{
	size_t pos = ps.save();
	try {
		return parseVariable(ps);
	} catch (CompilerError e) {
		try {
			if (e.neverIgnore) {
				throw e;
			}
			ps.restore(pos);
			return [parseFunction(ps, parseType(ps))];
		} catch (CompilerError ee) {
			if (ee.neverIgnore) {
				throw ee;
			}
			ps.restore(pos);
			return [parseExp(ps)];
		}
	}
}

ir.AssertStatement parseAssertStatement(ParserStream ps)
{
	auto as = new ir.AssertStatement();
	as.location = ps.peek.location;
	as.isStatic = matchIf(ps, TokenType.Static);
	match(ps, TokenType.Assert);
	match(ps, TokenType.OpenParen);
	as.condition = parseExp(ps);
	if (matchIf(ps, TokenType.Comma)) {
		as.message = parseExp(ps);
	}
	match(ps, TokenType.CloseParen);
	match(ps, TokenType.Semicolon);
	return as;
}

ir.ExpStatement parseExpStatement(ParserStream ps)
{
	auto e = new ir.ExpStatement();
	e.location = ps.peek.location;

	e.exp = parseExp(ps);
	eatComments(ps);
	match(ps, TokenType.Semicolon);

	return e;
}

ir.ReturnStatement parseReturnStatement(ParserStream ps)
{
	auto r = new ir.ReturnStatement();
	r.location = ps.peek.location;

	match(ps, TokenType.Return);

	// return;
	if (matchIf(ps, TokenType.Semicolon))
		return r;

	r.exp = parseExp(ps);
	match(ps, TokenType.Semicolon);

	return r;
}

ir.BlockStatement parseBlockStatement(ParserStream ps)
{
	auto bs = new ir.BlockStatement();
	bs.location = ps.peek.location;

	ps.pushCommentLevel();

	if (matchIf(ps, TokenType.OpenBrace)) {
		while (ps.peek.type != TokenType.CloseBrace) {
			bs.statements ~= parseStatement(ps);
		}
		match(ps, TokenType.CloseBrace);
	} else {
		bs.statements ~= parseStatement(ps);
	}

	ps.popCommentLevel();

	return bs;
}

ir.AsmStatement parseAsmStatement(ParserStream ps)
{
	auto as = new ir.AsmStatement();
	as.location = ps.peek.location;

	match(ps, TokenType.Asm);
	match(ps, TokenType.OpenBrace);
	while (ps.peek.type != TokenType.CloseBrace) {
		as.tokens ~= ps.get();
	}
	match(ps, TokenType.CloseBrace);

	return as;
}

ir.IfStatement parseIfStatement(ParserStream ps)
{
	auto i = new ir.IfStatement();
	i.location = ps.peek.location;

	match(ps, TokenType.If);
	match(ps, TokenType.OpenParen);
	if (matchIf(ps, TokenType.Auto)) {
		auto nameTok = match(ps, TokenType.Identifier);
		i.autoName = nameTok.value;
		match(ps, TokenType.Assign);
	}
	i.exp = parseExp(ps);
	match(ps, TokenType.CloseParen);
	i.thenState = parseBlockStatement(ps);
	if (matchIf(ps, TokenType.Else)) {
		i.elseState = parseBlockStatement(ps);
	}

	return i;
}

ir.WhileStatement parseWhileStatement(ParserStream ps)
{
	auto w = new ir.WhileStatement();
	w.location = ps.peek.location;

	match(ps, TokenType.While);
	match(ps, TokenType.OpenParen);
	w.condition = parseExp(ps);
	match(ps, TokenType.CloseParen);
	w.block = parseBlockStatement(ps);

	return w;
}

ir.DoStatement parseDoStatement(ParserStream ps)
{
	auto d = new ir.DoStatement();
	d.location = ps.peek.location;

	match(ps, TokenType.Do);
	d.block = parseBlockStatement(ps);
	match(ps, TokenType.While);
	match(ps, TokenType.OpenParen);
	d.condition = parseExp(ps);
	match(ps, TokenType.CloseParen);
	match(ps, TokenType.Semicolon);

	return d;
}

ir.ForeachStatement parseForeachStatement(ParserStream ps)
{
	auto f = new ir.ForeachStatement();
	f.location = ps.peek.location;

	f.reverse = matchIf(ps, TokenType.ForeachReverse);
	if (!f.reverse) {
		match(ps, TokenType.Foreach);
	}
	match(ps, TokenType.OpenParen);

	while (ps.peek.type != TokenType.Semicolon) {
		bool isRef = matchIf(ps, TokenType.Ref);
		ir.Type type;
		ir.Token name;
		if (ps == [TokenType.Identifier, TokenType.Comma] || ps == [TokenType.Identifier, TokenType.Semicolon]) {
			name = match(ps, TokenType.Identifier);
			auto st = new ir.StorageType();
			st.location = name.location;
			st.type = ir.StorageType.Kind.Auto;
			type = st;
		} else {
			type = parseType(ps);
			name = match(ps, TokenType.Identifier);
		}
		if (isRef) {
			auto st = new ir.StorageType();
			st.location = type.location;
			st.type = ir.StorageType.Kind.Ref;
			st.base = type;
			type = st;
		}
		f.itervars ~= new ir.Variable();
		f.itervars[$-1].location = type.location;
		f.itervars[$-1].type = type;
		f.itervars[$-1].name = name.value;
		matchIf(ps, TokenType.Comma);
	}
	match(ps, TokenType.Semicolon);

	auto firstExp = parseExp(ps);
	if (matchIf(ps, ir.TokenType.DoubleDot)) {
		f.beginIntegerRange = firstExp;
		f.endIntegerRange = parseExp(ps);
	} else {
		f.aggregate = firstExp;
	}

	match(ps, TokenType.CloseParen);
	f.block = parseBlockStatement(ps);
	return f;
}

ir.ForStatement parseForStatement(ParserStream ps)
{
	auto f = new ir.ForStatement();
	f.location = ps.peek.location;

	match(ps, TokenType.For);
	match(ps, TokenType.OpenParen);
	if (ps.peek.type != TokenType.Semicolon) {
		// for init -- parse declarations or assign expressions.
		ir.Node[] first;
		try {
			first = parseVariableOrExpression(ps);
		} catch (CompilerError e) {
			throw makeExpected(ps.peek.location, "declaration or expression");
		}
		if (first[0].nodeType != ir.NodeType.Variable) {
			f.initExps ~= cast(ir.Exp) first[0];
			assert(f.initExps[0] !is null);
			while (ps.peek.type != TokenType.Semicolon) {
				match(ps, TokenType.Comma);
				f.initExps ~= parseExp(ps);
			}
			match(ps, TokenType.Semicolon);
		} else {
			foreach (var; first) {
				f.initVars ~= cast(ir.Variable) var;
				assert(f.initVars[$-1] !is null);
			}
		}
	} else {
		match(ps, TokenType.Semicolon);
	}

	if (ps.peek.type != TokenType.Semicolon) {
		f.test = parseExp(ps);
	}
	match(ps, TokenType.Semicolon);

	while (ps.peek.type != TokenType.CloseParen) {
		f.increments ~= parseExp(ps);
		if (matchIf(ps, TokenType.Comma)) {}
	}
	match(ps, TokenType.CloseParen);

	f.block = parseBlockStatement(ps);

	return f;
}

ir.LabelStatement parseLabelStatement(ParserStream ps)
{
	auto ls = new ir.LabelStatement();
	ls.location = ps.peek.location;

	auto nameTok = match(ps, TokenType.Identifier);
	ls.label = nameTok.value;
	match(ps, TokenType.Colon);

	ls.childStatement ~= parseStatement(ps);

	return ls;
}

ir.SwitchStatement parseSwitchStatement(ParserStream ps)
{
	auto ss = new ir.SwitchStatement();
	ss.location = ps.peek.location;

	if (matchIf(ps, TokenType.Final)) {
		ss.isFinal = true;
	}

	match(ps, TokenType.Switch);
	match(ps, TokenType.OpenParen);
	ss.condition = parseExp(ps);
	match(ps, TokenType.CloseParen);

	while (matchIf(ps, TokenType.With)) {
		match(ps, TokenType.OpenParen);
		ss.withs ~= parseExp(ps);
		match(ps, TokenType.CloseParen);
	}

	match(ps, TokenType.OpenBrace);

	int braces = 1;  // Everybody gets one.
	while (matchIf(ps, TokenType.With)) {
		match(ps, TokenType.OpenParen);
		ss.withs ~= parseExp(ps);
		match(ps, TokenType.CloseParen);
		if (matchIf(ps, TokenType.OpenBrace)) {
			braces++;
		}
	}

	static ir.BlockStatement parseCaseStatements(ParserStream ps)
	{
		auto bs = new ir.BlockStatement();
		bs.location = ps.peek.location;
		while (true) {
			auto type = ps.peek.type;
			if (type == TokenType.Case ||
				type == TokenType.Default ||
				type == TokenType.CloseBrace) {
				break;
			}
			bs.statements ~= parseStatement(ps);
		}
		return bs;
	}

	bool hadDefault;
	while (ps.peek.type != TokenType.CloseBrace) {
		auto newCase = new ir.SwitchCase();
		newCase.location = ps.peek.location;
		switch (ps.peek.type) {
		case TokenType.Default:
			if (hadDefault) {
				throw makeMultipleDefaults(ps.peek.location);
			}
			if (ss.isFinal) {
				throw makeFinalSwitchWithDefault(ps.peek.location);
			}
			match(ps, TokenType.Default);
			match(ps, TokenType.Colon);
			hadDefault = true;
			newCase.isDefault = true;
			newCase.statements = parseCaseStatements(ps);
			ss.cases ~= newCase;
			break;
		case TokenType.Case:
			match(ps, TokenType.Case);
			ir.Exp[] exps;
			exps ~= parseExp(ps);
			if (matchIf(ps, TokenType.Comma)) {
				while (ps.peek.type != TokenType.Colon) {
					exps ~= parseExp(ps);
					if (ps.peek.type != TokenType.Colon) {
						match(ps, TokenType.Comma);
					}
				}
				match(ps, TokenType.Colon);
				newCase.exps = exps;
			} else {
				newCase.firstExp = exps[0];
				match(ps, TokenType.Colon);
				if (ps.peek.type == TokenType.DoubleDot) {
					match(ps, TokenType.DoubleDot);
					match(ps, TokenType.Case);
					newCase.secondExp = parseExp(ps);
					match(ps, TokenType.Colon);
				}
			}
			newCase.statements = parseCaseStatements(ps);
			ss.cases ~= newCase;
			break;
		case TokenType.CloseBrace:
			break;
		default:
			throw makeExpected(ps.peek.location, "'case', 'default', or '}'");
		}
	}
	while (braces--) {
		match(ps, TokenType.CloseBrace);
	}

	if (!ss.isFinal && !hadDefault) {
		throw makeNoDefaultCase(ss.location);
	}

	return ss;
}

ir.ContinueStatement parseContinueStatement(ParserStream ps)
{
	auto cs = new ir.ContinueStatement();
	cs.location = ps.peek.location;

	match(ps, TokenType.Continue);
	if (ps.peek.type == TokenType.Identifier) {
		auto nameTok = match(ps, TokenType.Identifier);
		cs.label = nameTok.value;
	}
	match(ps, TokenType.Semicolon);

	return cs;
}

ir.BreakStatement parseBreakStatement(ParserStream ps)
{
	auto bs = new ir.BreakStatement();
	bs.location = ps.peek.location;

	match(ps, TokenType.Break);
	if (ps.peek.type == TokenType.Identifier) {
		auto nameTok = match(ps, TokenType.Identifier);
		bs.label = nameTok.value;
	}
	match(ps, TokenType.Semicolon);

	return bs;
}

ir.GotoStatement parseGotoStatement(ParserStream ps)
{
	auto gs = new ir.GotoStatement();
	gs.location = ps.peek.location;

	match(ps, TokenType.Goto);
	switch (ps.peek.type) {
	case TokenType.Identifier:
		throw makeUnsupported(ps.peek.location, "goto statement");
		version (none) {
			auto nameTok = match(ps, TokenType.Identifier);
			gs.label = nameTok.value;
			break;
		}
	case TokenType.Default:
		match(ps, TokenType.Default);
		gs.isDefault = true;
		break;
	case TokenType.Case:
		match(ps, TokenType.Case);
		gs.isCase = true;
		if (ps.peek.type != TokenType.Semicolon) {
			gs.exp = parseExp(ps);
		}
		break;
	default:
		throw makeExpected(ps.peek.location, "identifier, 'case', or 'default'.");
	}
	match(ps, TokenType.Semicolon);

	return gs;
}

ir.WithStatement parseWithStatement(ParserStream ps)
{
	auto ws = new ir.WithStatement();
	ws.location = ps.peek.location;

	match(ps, TokenType.With);
	match(ps, TokenType.OpenParen);
	ws.exp = parseExp(ps);
	match(ps, TokenType.CloseParen);
	ws.block = parseBlockStatement(ps);

	return ws;
}

ir.SynchronizedStatement parseSynchronizedStatement(ParserStream ps)
{
	auto ss = new ir.SynchronizedStatement();
	ss.location = ps.peek.location;

	match(ps, TokenType.Synchronized);
	if (matchIf(ps, TokenType.OpenParen)) {
		ss.exp = parseExp(ps);
		match(ps, TokenType.CloseParen);
	}
	ss.block = parseBlockStatement(ps);
	assert(ss.block !is null);

	return ss;
}

ir.TryStatement parseTryStatement(ParserStream ps)
{
	auto t = new ir.TryStatement();
	t.location = ps.peek.location;

	match(ps, TokenType.Try);
	t.tryBlock = parseBlockStatement(ps);

	while (matchIf(ps, TokenType.Catch)) {
		if (matchIf(ps, TokenType.OpenParen)) {
			auto var = new ir.Variable();
			var.location = ps.peek.location;
			var.type = parseType(ps);
			var.specialInitValue = true;
			if (ps.peek.type != TokenType.CloseParen) {
				auto nameTok = match(ps, TokenType.Identifier);
				var.name = nameTok.value;
			} else {
				var.name = "1__dummy";
			}
			match(ps, TokenType.CloseParen);
			auto bs = parseBlockStatement(ps);
			bs.statements = var ~ bs.statements;
			t.catchVars ~= var;
			t.catchBlocks ~= bs;
		} else {
			t.catchAll = parseBlockStatement(ps);
			if (ps.peek.type == TokenType.Catch) {
				throw new CompilerError(ps.peek.location, "catch all block must be last catch block in try statement.");
			}
		}
	}

	if (matchIf(ps, TokenType.Finally)) {
		t.finallyBlock = parseBlockStatement(ps);
	}

	if (t.catchBlocks.length == 0 && t.catchAll is null && t.finallyBlock is null) {
		throw makeTryWithoutCatch(t.location);
	}

	return t;
}

ir.ThrowStatement parseThrowStatement(ParserStream ps)
{
	auto t = new ir.ThrowStatement();
	t.location = ps.peek.location;
	match(ps, TokenType.Throw);
	t.exp = parseExp(ps);
	match(ps, TokenType.Semicolon);
	return t;
}

ir.ScopeStatement parseScopeStatement(ParserStream ps)
{
	auto ss = new ir.ScopeStatement();
	ss.location = ps.peek.location;

	match(ps, TokenType.Scope);
	match(ps, TokenType.OpenParen);
	auto nameTok = match(ps, TokenType.Identifier);
	switch (nameTok.value) with (ir.ScopeStatement.Kind) {
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
		throw makeExpected(ps.peek.location, "'exit', 'success', or 'failure'");
	}
	match(ps, TokenType.CloseParen);
	ss.block = parseBlockStatement(ps);

	return ss;
}

ir.PragmaStatement parsePragmaStatement(ParserStream ps)
{
	auto prs = new ir.PragmaStatement();
	prs.location = ps.peek.location;

	match(ps, TokenType.Pragma);
	match(ps, TokenType.OpenParen);
	auto nameTok = match(ps, TokenType.Identifier);
	prs.type = nameTok.value;
	if (matchIf(ps, TokenType.Comma)) {
		prs.arguments = parseArgumentList(ps);
	}
	match(ps, TokenType.CloseParen);
	prs.block = parseBlockStatement(ps);

	return prs;
}

ir.ConditionStatement parseConditionStatement(ParserStream ps)
{
	auto cs = new ir.ConditionStatement();
	cs.location = ps.peek.location;

	cs.condition = parseCondition(ps);
	cs.block = parseBlockStatement(ps);
	if (matchIf(ps, TokenType.Else)) {
		cs._else = parseBlockStatement(ps);
	}

	return cs;
}

ir.MixinStatement parseMixinStatement(ParserStream ps)
{
	auto ms = new ir.MixinStatement();
	ms.location = ps.peek.location;
	match(ps, TokenType.Mixin);
	
	if (matchIf(ps, TokenType.OpenParen)) {
		ms.stringExp = parseExp(ps);
		match(ps, TokenType.CloseParen);
	} else {
		auto ident = match(ps, TokenType.Identifier);

		auto qualifiedName = new ir.QualifiedName();
		qualifiedName.identifiers ~= new ir.Identifier(ident.value);

		ms.id = qualifiedName;

		match(ps, TokenType.Bang);
		// TODO
		match(ps, TokenType.OpenParen);
		match(ps, TokenType.CloseParen);
	}
	match(ps, TokenType.Semicolon);
	
	return ms;
}
