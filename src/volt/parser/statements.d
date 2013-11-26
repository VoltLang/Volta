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


ir.Statement[] parseStatement(TokenStream ts)
{
	switch (ts.peek.type) {
	case TokenType.Semicolon:
		return [parseEmptyStatement(ts)];
	case TokenType.Return:
		return [parseReturnStatement(ts)];
	case TokenType.OpenBrace:
		return [parseBlockStatement(ts)];
	case TokenType.Asm:
		return [parseAsmStatement(ts)];
	case TokenType.If:
		return [parseIfStatement(ts)];
	case TokenType.While:
		return [parseWhileStatement(ts)];
	case TokenType.Do:
		return [parseDoStatement(ts)];
	case TokenType.For:
		return [parseForStatement(ts)];
	case TokenType.Foreach, TokenType.ForeachReverse:
		return [parseForeachStatement(ts)];
	case TokenType.Switch:
		return [parseSwitchStatement(ts)];
	case TokenType.Break:
		return [parseBreakStatement(ts)];
	case TokenType.Continue:
		return [parseContinueStatement(ts)];
	case TokenType.Goto:
		return [parseGotoStatement(ts)];
	case TokenType.With:
		return [parseWithStatement(ts)];
	case TokenType.Synchronized:
		return [parseSynchronizedStatement(ts)];
	case TokenType.Try:
		return [parseTryStatement(ts)];
	case TokenType.Throw:
		return [parseThrowStatement(ts)];
	case TokenType.Scope:
		if (ts.lookahead(1).type == TokenType.OpenParen && ts.lookahead(2).type == TokenType.Identifier &&
			ts.lookahead(3).type == TokenType.CloseParen) {
			auto identTok = ts.lookahead(2);
			if (identTok.value == "exit" || identTok.value == "failure" || identTok.value == "success") {
				return [parseScopeStatement(ts)];
			}
		}
		goto default;
	case TokenType.Pragma:
		return [parsePragmaStatement(ts)];
	case TokenType.Identifier:
		if (ts.lookahead(1).type == TokenType.Colon) {
			return [parseLabelStatement(ts)];
		} else {
			goto default;
		}
	case TokenType.Final:
		if (ts.lookahead(1).type == TokenType.Switch) {
			goto case TokenType.Switch;
		} else {
			goto default;
		}
	case TokenType.Static:
		if (ts.lookahead(1).type == TokenType.If) {
			goto case TokenType.Version;
		} else if (ts.lookahead(1).type == TokenType.Assert) {
			goto case TokenType.Assert;
		} else {
			goto default;
		}
	case TokenType.Assert:
		return [parseAssertStatement(ts)];
	case TokenType.Version:
	case TokenType.Debug:
		ir.Statement[] condstate = [parseConditionStatement(ts)];
		return condstate;
	case TokenType.Mixin:
		return [parseMixinStatement(ts)];
	default:
		ir.Node[] node = parseVariableOrExpression(ts);
		if (node[0].nodeType != ir.NodeType.Variable && node[0].nodeType != ir.NodeType.Function) {
			// create an ExpStatement out of an Expression
			match(ts, TokenType.Semicolon);
			auto es = new ir.ExpStatement();
			es.location = node[0].location;
			auto asExp = cast(ir.Exp) node[0];
			assert(asExp !is null);
			es.exp = asExp;
			return [es];

		} else {
			// return a regular declaration
			return cast(ir.Statement[]) node;
		}
	}
}

/* Try to parse as a declaration first because
 *   Object* a;
 * Is always a declaration. If you do something like
 *   int a, b;
 *   a * b;
 * An error like "a used as type" should be emitted.
 */
ir.Node[] parseVariableOrExpression(TokenStream ts)
{
	size_t pos = ts.save();
	try {
		return parseVariable(ts);
	} catch (CompilerError e) {
		try {
			if (e.neverIgnore) {
				throw e;
			}
			ts.restore(pos);
			return [parseFunction(ts, parseType(ts))];
		} catch (CompilerError ee) {
			if (ee.neverIgnore) {
				throw ee;
			}
			ts.restore(pos);
			return [parseExp(ts)];
		}
	}
}

ir.AssertStatement parseAssertStatement(TokenStream ts)
{
	auto as = new ir.AssertStatement();
	as.location = ts.peek.location;
	as.isStatic = matchIf(ts, TokenType.Static);
	match(ts, TokenType.Assert);
	match(ts, TokenType.OpenParen);
	as.condition = parseExp(ts);
	if (matchIf(ts, TokenType.Comma)) {
		as.message = parseExp(ts);
	}
	match(ts, TokenType.CloseParen);
	match(ts, TokenType.Semicolon);
	return as;
}

ir.ExpStatement parseExpStatement(TokenStream ts)
{
	auto e = new ir.ExpStatement();
	e.location = ts.peek.location;

	e.exp = parseExp(ts);
	match(ts, TokenType.Semicolon);

	return e;
}

ir.ReturnStatement parseReturnStatement(TokenStream ts)
{
	auto r = new ir.ReturnStatement();
	r.location = ts.peek.location;

	match(ts, TokenType.Return);

	// return;
	if (matchIf(ts, TokenType.Semicolon))
		return r;

	r.exp = parseExp(ts);
	match(ts, TokenType.Semicolon);

	return r;
}

ir.BlockStatement parseBlockStatement(TokenStream ts)
{
	auto bs = new ir.BlockStatement();
	bs.location = ts.peek.location;

	if (matchIf(ts, TokenType.OpenBrace)) {
		while (ts.peek.type != TokenType.CloseBrace) {
			bs.statements ~= parseStatement(ts);
		}
		match(ts, TokenType.CloseBrace);
	} else {
		bs.statements ~= parseStatement(ts);
	}

	return bs;
}

ir.AsmStatement parseAsmStatement(TokenStream ts)
{
	auto as = new ir.AsmStatement();
	as.location = ts.peek.location;

	match(ts, TokenType.Asm);
	match(ts, TokenType.OpenBrace);
	while (ts.peek.type != TokenType.CloseBrace) {
		as.tokens ~= ts.get();
	}
	match(ts, TokenType.CloseBrace);

	return as;
}

ir.IfStatement parseIfStatement(TokenStream ts)
{
	auto i = new ir.IfStatement();
	i.location = ts.peek.location;

	match(ts, TokenType.If);
	match(ts, TokenType.OpenParen);
	if (matchIf(ts, TokenType.Auto)) {
		auto nameTok = match(ts, TokenType.Identifier);
		i.autoName = nameTok.value;
		match(ts, TokenType.Assign);
	}
	i.exp = parseExp(ts);
	match(ts, TokenType.CloseParen);
	i.thenState = parseBlockStatement(ts);
	if (matchIf(ts, TokenType.Else)) {
		i.elseState = parseBlockStatement(ts);
	}

	return i;
}

ir.WhileStatement parseWhileStatement(TokenStream ts)
{
	auto w = new ir.WhileStatement();
	w.location = ts.peek.location;

	match(ts, TokenType.While);
	match(ts, TokenType.OpenParen);
	w.condition = parseExp(ts);
	match(ts, TokenType.CloseParen);
	w.block = parseBlockStatement(ts);

	return w;
}

ir.DoStatement parseDoStatement(TokenStream ts)
{
	auto d = new ir.DoStatement();
	d.location = ts.peek.location;

	match(ts, TokenType.Do);
	d.block = parseBlockStatement(ts);
	match(ts, TokenType.While);
	match(ts, TokenType.OpenParen);
	d.condition = parseExp(ts);
	match(ts, TokenType.CloseParen);
	match(ts, TokenType.Semicolon);

	return d;
}

ir.ForeachStatement parseForeachStatement(TokenStream ts)
{
	auto f = new ir.ForeachStatement();
	f.location = ts.peek.location;

	f.reverse = matchIf(ts, TokenType.ForeachReverse);
	if (!f.reverse) {
		match(ts, TokenType.Foreach);
	}
	match(ts, TokenType.OpenParen);

	while (ts.peek.type != TokenType.Semicolon) {
		bool isRef = matchIf(ts, TokenType.Ref);
		ir.Type type;
		ir.Token name;
		if (ts == [TokenType.Identifier, TokenType.Comma] || ts == [TokenType.Identifier, TokenType.Semicolon]) {
			name = match(ts, TokenType.Identifier);
			auto st = new ir.StorageType();
			st.location = name.location;
			st.type = ir.StorageType.Kind.Auto;
			type = st;
		} else {
			type = parseType(ts);
			name = match(ts, TokenType.Identifier);
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
		matchIf(ts, TokenType.Comma);
	}
	match(ts, TokenType.Semicolon);

	auto firstExp = parseExp(ts);
	if (matchIf(ts, ir.TokenType.DoubleDot)) {
		f.beginIntegerRange = firstExp;
		f.endIntegerRange = parseExp(ts);
	} else {
		f.aggregate = firstExp;
	}

	match(ts, TokenType.CloseParen);
	f.block = parseBlockStatement(ts);
	return f;
}

ir.ForStatement parseForStatement(TokenStream ts)
{
	auto f = new ir.ForStatement();
	f.location = ts.peek.location;

	match(ts, TokenType.For);
	match(ts, TokenType.OpenParen);
	if (ts.peek.type != TokenType.Semicolon) {
		// for init -- parse declarations or assign expressions.
		ir.Node[] first;
		try {
			first = parseVariableOrExpression(ts);
		} catch (CompilerError e) {
			throw makeExpected(ts.peek.location, "declaration or expression");
		}
		if (first[0].nodeType != ir.NodeType.Variable) {
			f.initExps ~= cast(ir.Exp) first[0];
			assert(f.initExps[0] !is null);
			while (ts.peek.type != TokenType.Semicolon) {
				match(ts, TokenType.Comma);
				f.initExps ~= parseExp(ts);
			}
			match(ts, TokenType.Semicolon);
		} else {
			foreach (var; first) {
				f.initVars ~= cast(ir.Variable) var;
				assert(f.initVars[$-1] !is null);
			}
		}
	} else {
		match(ts, TokenType.Semicolon);
	}

	if (ts.peek.type != TokenType.Semicolon) {
		f.test = parseExp(ts);
	}
	match(ts, TokenType.Semicolon);

	while (ts.peek.type != TokenType.CloseParen) {
		f.increments ~= parseExp(ts);
		if (matchIf(ts, TokenType.Comma)) {}
	}
	match(ts, TokenType.CloseParen);

	f.block = parseBlockStatement(ts);

	return f;
}

ir.LabelStatement parseLabelStatement(TokenStream ts)
{
	auto ls = new ir.LabelStatement();
	ls.location = ts.peek.location;

	auto nameTok = match(ts, TokenType.Identifier);
	ls.label = nameTok.value;
	match(ts, TokenType.Colon);

	ls.childStatement ~= parseStatement(ts);

	return ls;
}

ir.SwitchStatement parseSwitchStatement(TokenStream ts)
{
	auto ss = new ir.SwitchStatement();
	ss.location = ts.peek.location;

	if (matchIf(ts, TokenType.Final)) {
		ss.isFinal = true;
	}

	match(ts, TokenType.Switch);
	match(ts, TokenType.OpenParen);
	ss.condition = parseExp(ts);
	match(ts, TokenType.CloseParen);

	while (matchIf(ts, TokenType.With)) {
		match(ts, TokenType.OpenParen);
		ss.withs ~= parseExp(ts);
		match(ts, TokenType.CloseParen);
	}

	match(ts, TokenType.OpenBrace);

	int braces = 1;  // Everybody gets one.
	while (matchIf(ts, TokenType.With)) {
		match(ts, TokenType.OpenParen);
		ss.withs ~= parseExp(ts);
		match(ts, TokenType.CloseParen);
		if (matchIf(ts, TokenType.OpenBrace)) {
			braces++;
		}
	}

	static ir.BlockStatement parseCaseStatements(TokenStream ts)
	{
		auto bs = new ir.BlockStatement();
		bs.location = ts.peek.location;
		while (true) {
			auto type = ts.peek.type;
			if (type == TokenType.Case ||
				type == TokenType.Default ||
				type == TokenType.CloseBrace) {
				break;
			}
			bs.statements ~= parseStatement(ts);
		}
		return bs;
	}

	bool hadDefault;
	while (ts.peek.type != TokenType.CloseBrace) {
		auto newCase = new ir.SwitchCase();
		newCase.location = ts.peek.location;
		switch (ts.peek.type) {
		case TokenType.Default:
			if (hadDefault) {
				throw makeMultipleDefaults(ts.peek.location);
			}
			if (ss.isFinal) {
				throw makeFinalSwitchWithDefault(ts.peek.location);
			}
			match(ts, TokenType.Default);
			match(ts, TokenType.Colon);
			hadDefault = true;
			newCase.isDefault = true;
			newCase.statements = parseCaseStatements(ts);
			ss.cases ~= newCase;
			break;
		case TokenType.Case:
			match(ts, TokenType.Case);
			ir.Exp[] exps;
			exps ~= parseExp(ts);
			if (matchIf(ts, TokenType.Comma)) {
				while (ts.peek.type != TokenType.Colon) {
					exps ~= parseExp(ts);
					if (ts.peek.type != TokenType.Colon) {
						match(ts, TokenType.Comma);
					}
				}
				match(ts, TokenType.Colon);
				newCase.exps = exps;
			} else {
				newCase.firstExp = exps[0];
				match(ts, TokenType.Colon);
				if (ts.peek.type == TokenType.DoubleDot) {
					match(ts, TokenType.DoubleDot);
					match(ts, TokenType.Case);
					newCase.secondExp = parseExp(ts);
					match(ts, TokenType.Colon);
				}
			}
			newCase.statements = parseCaseStatements(ts);
			ss.cases ~= newCase;
			break;
		case TokenType.CloseBrace:
			break;
		default:
			throw makeExpected(ts.peek.location, "'case', 'default', or '}'");
		}
	}
	while (braces--) {
		match(ts, TokenType.CloseBrace);
	}

	if (!ss.isFinal && !hadDefault) {
		throw makeNoDefaultCase(ss.location);
	}

	return ss;
}

ir.ContinueStatement parseContinueStatement(TokenStream ts)
{
	auto cs = new ir.ContinueStatement();
	cs.location = ts.peek.location;

	match(ts, TokenType.Continue);
	if (ts.peek.type == TokenType.Identifier) {
		auto nameTok = match(ts, TokenType.Identifier);
		cs.label = nameTok.value;
	}
	match(ts, TokenType.Semicolon);

	return cs;
}

ir.BreakStatement parseBreakStatement(TokenStream ts)
{
	auto bs = new ir.BreakStatement();
	bs.location = ts.peek.location;

	match(ts, TokenType.Break);
	if (ts.peek.type == TokenType.Identifier) {
		auto nameTok = match(ts, TokenType.Identifier);
		bs.label = nameTok.value;
	}
	match(ts, TokenType.Semicolon);

	return bs;
}

ir.GotoStatement parseGotoStatement(TokenStream ts)
{
	auto gs = new ir.GotoStatement();
	gs.location = ts.peek.location;

	match(ts, TokenType.Goto);
	switch (ts.peek.type) {
	case TokenType.Identifier:
		auto nameTok = match(ts, TokenType.Identifier);
		gs.label = nameTok.value;
		break;
	case TokenType.Default:
		match(ts, TokenType.Default);
		gs.isDefault = true;
		break;
	case TokenType.Case:
		match(ts, TokenType.Case);
		gs.isCase = true;
		if (ts.peek.type != TokenType.Semicolon) {
			gs.exp = parseExp(ts);
		}
		break;
	default:
		throw makeExpected(ts.peek.location, "identifier, 'case', or 'default'.");
	}
	match(ts, TokenType.Semicolon);

	return gs;
}

ir.WithStatement parseWithStatement(TokenStream ts)
{
	auto ws = new ir.WithStatement();
	ws.location = ts.peek.location;

	match(ts, TokenType.With);
	match(ts, TokenType.OpenParen);
	ws.exp = parseExp(ts);
	match(ts, TokenType.CloseParen);
	ws.block = parseBlockStatement(ts);

	return ws;
}

ir.SynchronizedStatement parseSynchronizedStatement(TokenStream ts)
{
	auto ss = new ir.SynchronizedStatement();
	ss.location = ts.peek.location;

	match(ts, TokenType.Synchronized);
	if (matchIf(ts, TokenType.OpenParen)) {
		ss.exp = parseExp(ts);
		match(ts, TokenType.CloseParen);
	}
	ss.block = parseBlockStatement(ts);
	assert(ss.block !is null);

	return ss;
}

ir.TryStatement parseTryStatement(TokenStream ts)
{
	auto t = new ir.TryStatement();
	t.location = ts.peek.location;

	match(ts, TokenType.Try);
	t.tryBlock = parseBlockStatement(ts);

	while (matchIf(ts, TokenType.Catch)) {
		if (matchIf(ts, TokenType.OpenParen)) {
			auto var = new ir.Variable();
			var.location = ts.peek.location;
			var.type = parseType(ts);
			if (ts.peek.type != TokenType.CloseParen) {
				auto nameTok = match(ts, TokenType.Identifier);
				var.name = nameTok.value;
			} else {
				var.name = "1__dummy";
			}
			match(ts, TokenType.CloseParen);
			t.catchVars ~= var;
			t.catchBlocks ~= parseBlockStatement(ts);
		} else {
			t.catchAll = parseBlockStatement(ts);
			if (ts.peek.type == TokenType.Catch) {
				throw new CompilerError(ts.peek.location, "catch all block must be last catch block in try statement.");
			}
		}
	}

	if (matchIf(ts, TokenType.Finally)) {
		t.finallyBlock = parseBlockStatement(ts);
	}

	if (t.catchBlocks.length == 0 && t.catchAll is null && t.finallyBlock is null) {
		throw makeTryWithoutCatch(t.location);
	}

	return t;
}

ir.ThrowStatement parseThrowStatement(TokenStream ts)
{
	auto t = new ir.ThrowStatement();
	t.location = ts.peek.location;
	match(ts, TokenType.Throw);
	t.exp = parseExp(ts);
	match(ts, TokenType.Semicolon);
	return t;
}

ir.ScopeStatement parseScopeStatement(TokenStream ts)
{
	auto ss = new ir.ScopeStatement();
	ss.location = ts.peek.location;

	match(ts, TokenType.Scope);
	match(ts, TokenType.OpenParen);
	auto nameTok = match(ts, TokenType.Identifier);
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
		throw makeExpected(ts.peek.location, "'exit', 'success', or 'failure'");
	}
	match(ts, TokenType.CloseParen);
	ss.block = parseBlockStatement(ts);

	return ss;
}

ir.PragmaStatement parsePragmaStatement(TokenStream ts)
{
	auto ps = new ir.PragmaStatement();
	ps.location = ts.peek.location;

	match(ts, TokenType.Pragma);
	match(ts, TokenType.OpenParen);
	auto nameTok = match(ts, TokenType.Identifier);
	ps.type = nameTok.value;
	if (matchIf(ts, TokenType.Comma)) {
		ps.arguments = parseArgumentList(ts);
	}
	match(ts, TokenType.CloseParen);
	ps.block = parseBlockStatement(ts);

	return ps;
}

ir.EmptyStatement parseEmptyStatement(TokenStream ts)
{
	auto es = new ir.EmptyStatement();
	es.location = ts.peek.location;

	match(ts, TokenType.Semicolon);

	return es;
}

ir.ConditionStatement parseConditionStatement(TokenStream ts)
{
	auto cs = new ir.ConditionStatement();
	cs.location = ts.peek.location;

	cs.condition = parseCondition(ts);
	cs.block = parseBlockStatement(ts);
	if (matchIf(ts, TokenType.Else)) {
		cs._else = parseBlockStatement(ts);
	}

	return cs;
}

ir.MixinStatement parseMixinStatement(TokenStream ts)
{
	auto ms = new ir.MixinStatement();
	ms.location = ts.peek.location;
	match(ts, TokenType.Mixin);
	
	if (matchIf(ts, TokenType.OpenParen)) {
		ms.stringExp = parseExp(ts);
		match(ts, TokenType.CloseParen);
	} else {
		auto ident = match(ts, TokenType.Identifier);

		auto qualifiedName = new ir.QualifiedName();
		qualifiedName.identifiers ~= new ir.Identifier(ident.value);

		ms.id = qualifiedName;

		match(ts, TokenType.Bang);
		// TODO
		match(ts, TokenType.OpenParen);
		match(ts, TokenType.CloseParen);
	}
	match(ts, TokenType.Semicolon);
	
	return ms;
}
