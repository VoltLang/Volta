// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.declaration;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.exceptions;
import volt.errors;
import volt.token.stream;

import volt.parser.base;
import volt.parser.expression;
import volt.parser.toplevel;
import volt.parser.declaration;
import volt.parser.statements;
import volt.token.location;
import volt.semantic.classify;


ir.Node[] parseVariable(TokenStream ts)
{
	if (ts.peek.type == TokenType.Alias) {
		return [parseAlias(ts)];
	}

	ir.Type base = parseType(ts);
	if (ts.lookahead(1).type == TokenType.Comma ||
		ts.lookahead(1).type == TokenType.Semicolon ||
		ts.lookahead(1).type == TokenType.Assign) {
		// Normal declaration.
		return reallyParseVariable(ts, base);
	} else if (ts.lookahead(1).type == TokenType.OpenParen) {
		// Function!
		return [parseFunction(ts, base)];
	} else {
		throw makeExpected(ts.peek.location, "declaration");
	}
}

ir.Variable[] parseJustVariable(TokenStream ts)
{
	ir.Type base = parseType(ts);
	ir.Node[] nodes = reallyParseVariable(ts, base);
	auto vars = new ir.Variable[nodes.length];
	foreach (i, node; nodes) {
		vars[i] = cast(ir.Variable) node;
		assert(vars[i] !is null, "reallyParseVariable parsed non variable");
	}
	return vars;
}

ir.Alias parseAlias(TokenStream ts)
{
	auto a = new ir.Alias();
	a.location = ts.peek.location;

	match(ts, TokenType.Alias);
	auto nameTok = match(ts, TokenType.Identifier);
	a.name = nameTok.value;
	match(ts, TokenType.Assign);

	size_t pos = ts.save();
	try {
		a.id = parseQualifiedName(ts);
		match(ts, TokenType.Semicolon);

	} catch (CompilerError e) {
		if (e.neverIgnore) {
			throw e;
		}
		ts.restore(pos);

		a.id = null;
		a.type = parseType(ts);
		match(ts, TokenType.Semicolon);
	}

	return a;
}

ir.Node[] reallyParseVariable(TokenStream ts, ir.Type base)
{
	ir.Node[] decls;

	while (true) {
		auto d = new ir.Variable();
		d.location = ts.peek.location;
		d.type = base;
		auto nameTok = match(ts, TokenType.Identifier);
		d.name = nameTok.value;
		if (ts.peek.type == TokenType.Assign) {
			match(ts, TokenType.Assign);
			try {
				d.assign = parseExp(ts);
			} catch (CompilerError e) {
				throw new CompilerError(e.location, e.msg, e, true);
			}
		}
		decls ~= d;

		if (ts.peek.type == TokenType.Comma) {
			// Need to copy this on multiple.
			base = copyType(base);
			ts.get();
		} else {
			break;
		}
	}
	match(ts, TokenType.Semicolon);

	return decls;
}

ir.Type parseType(TokenStream ts)
{
	Location origin = ts.peek.location;

	ir.Type base;
	switch (ts.peek.type) {
	case TokenType.Void, TokenType.Char, TokenType.Byte, TokenType.Ubyte,
		 TokenType.Short, TokenType.Ushort, TokenType.Int, TokenType.Uint,
		 TokenType.Long, TokenType.Ulong, TokenType.Float, TokenType.Double,
		 TokenType.Real, TokenType.Bool, TokenType.Wchar, TokenType.Dchar:
		base = parsePrimitiveType(ts);
		break;
	case TokenType.Auto, TokenType.Const, TokenType.Immutable,
		 TokenType.Scope:
		base = parseStorageType(ts);
		break;
	case TokenType.Identifier, TokenType.Dot:
		base = parseTypeReference(ts);
		break;
	case TokenType.Typeof:
		base = parseTypeOf(ts);
		break;
	default:
		throw makeExpected(ts.peek.location, "primitive type");
	}

	base = parseTypeSigils(ts, origin, base);

	switch (ts.peek.type) {
	case TokenType.Function:
		base = parseFunctionType(ts, base);
		base.location = ts.peek.location - origin;
		base = parseTypeSigils(ts, origin, base);
		break;
	case TokenType.Delegate:
		base = parseDelegateType(ts, base);
		base.location = ts.peek.location - origin;
		base = parseTypeSigils(ts, origin, base);
		break;
	default:
		break;
	}

	base.location = ts.peek.location - origin;

	return base;
}

ir.TypeOf parseTypeOf(TokenStream ts)
{
	auto typeOf = new ir.TypeOf();
	typeOf.location = ts.peek.location;
	match(ts, TokenType.Typeof);
	match(ts, TokenType.OpenParen);
	typeOf.exp = parseExp(ts);
	match(ts, TokenType.CloseParen);
	return typeOf;
}

ir.TypeReference parseTypeReference(TokenStream ts)
{
	auto typeReference = new ir.TypeReference();
	typeReference.location = ts.peek.location;

	typeReference.id = parseQualifiedName(ts, true);

	assert(typeReference.id.identifiers.length > 0);
	return typeReference;
}

ir.StorageType parseStorageType(TokenStream ts)
{
	auto storageType = new ir.StorageType();
	storageType.location = ts.peek.location;

	storageType.type = cast(ir.StorageType.Kind) ts.peek.type;
	ts.get();

	if (ts == [TokenType.Identifier, TokenType.Semicolon] ||
		ts == [TokenType.Identifier, TokenType.Assign, TokenType.Void, TokenType.Semicolon]) {
		throw makeCannotInfer(ts.peek.location);
	} else if (matchIf(ts, TokenType.OpenParen)) {
		storageType.base = parseType(ts);
		match(ts, TokenType.CloseParen);
	} else if (!(ts == [TokenType.Identifier, TokenType.Assign])) {
		storageType.base = parseType(ts);
	}

	return storageType;
}

ir.FunctionType parseFunctionType(TokenStream ts, ir.Type base)
{
	auto fn = new ir.FunctionType();
	fn.location = ts.peek.location;

	fn.ret = base;
	match(ts, TokenType.Function);
	fn.params = parseParameterListFPtr(ts, fn);

	return fn;
}

ir.DelegateType parseDelegateType(TokenStream ts, ir.Type base)
{
	auto fn = new ir.DelegateType();
	fn.location = ts.peek.location;

	fn.ret = base;
	match(ts, TokenType.Delegate);
	fn.params = parseParameterListFPtr(ts, fn);

	return fn;
}

ir.Type[] parseParameterListFPtr(TokenStream ts, ir.CallableType parentCallable)
{
	ir.Type[] types;

	match(ts, TokenType.OpenParen);
	while (ts.peek.type != TokenType.CloseParen) {
		if (matchIf(ts, TokenType.TripleDot)) {
			parentCallable.hasVarArgs = true;
			break;
		}
		auto var = parseParameter(ts);
		types ~= var.type;
		if (ts.peek.type == TokenType.Comma) {
			ts.get();
		}
	}
	match(ts, TokenType.CloseParen);

	return types;
}

ir.Variable[] parseParameterList(TokenStream ts, ir.CallableType parentCallable)
{
	ir.Variable[] vars;

	match(ts, TokenType.OpenParen);
	while (ts.peek.type != TokenType.CloseParen) {
		if (matchIf(ts, TokenType.TripleDot)) {
			if (parentCallable is null) {
				throw makeExpected(ts.peek.location, "function or delegate");
			}
			parentCallable.hasVarArgs = true;
			break;
		}
		auto var = parseParameter(ts);
		// foo(int a, int[] b...)
		if (matchIf(ts, TokenType.TripleDot)) {
			if (!isArray(var.type)) {
				throw makeExpected(ts.peek.location, "array argument for homogenous variadic");
			}
			if (ts.peek.type != TokenType.CloseParen) {
				throw makeExpected(ts.peek.location, "homogenous variadic argument to be final argument");
			}
			parentCallable.hasVarArgs = false;
			parentCallable.homogenousVariadic = true;
		}
		vars ~= var;
		// foo(int a, int b, ...)
		if (ts.peek.type == TokenType.Comma) {
			ts.get();
			if (matchIf(ts, TokenType.TripleDot)) {
				if (ts.peek.type != TokenType.CloseParen) {
					throw makeExpected(ts.peek.location, "var args to be last argument");
				}
				parentCallable.hasVarArgs = true;
			}
		}
	}
	match(ts, TokenType.CloseParen);

	return vars;
}

ir.Variable parseParameter(TokenStream ts)
{
	ir.Variable p = new ir.Variable();
	p.storage = ir.Variable.Storage.Function;
	Location origin = ts.peek.location;

	/// @todo intermixed ref
	bool isOut, isIn, isRef;
	isRef = matchIf(ts, TokenType.Ref);
	if (!isRef) {
		isOut = matchIf(ts, TokenType.Out);
	}
	if (!isOut && !isRef) {
		isIn = matchIf(ts, TokenType.In);
	}

	p.type = parseType(ts);
	if (isRef || isOut) {
		auto s = new ir.StorageType();
		s.location = p.type.location;
		s.type = isRef ? ir.StorageType.Kind.Ref : ir.StorageType.Kind.Out;
		s.base = p.type;
		p.type = s;
	}
	if (isIn) {
		auto constStorage = buildStorageType(ts.peek.location, ir.StorageType.Kind.Const, p.type);
		auto scopeStorage = buildStorageType(ts.peek.location, ir.StorageType.Kind.Scope, constStorage);
		p.type = scopeStorage;
	}
	if (ts.peek.type == TokenType.Identifier) {
		Token name = match(ts, TokenType.Identifier);
		p.name = name.value;
		if (matchIf(ts, TokenType.Assign)) {
			p.assign = parseExp(ts);
		}
	} else if (ts.peek.type != TokenType.Comma && ts.peek.type != TokenType.CloseParen) {
		throw makeExpected(ts.peek.location, "',', ')', or an identifier", ts.peek.value);
	}
	p.location = ts.peek.location - origin;

	return p;
}

// Parse things that go on the end of types like * or []. If none, base is returned.
ir.Type parseTypeSigils(TokenStream ts, Location origin, ir.Type base)
{
	LOOP: while (true) switch (ts.peek.type) {
	case TokenType.Asterix:
		auto end = ts.get();
		auto p = new ir.PointerType();
		p.location = end.location - origin;
		p.base = base;
		base = p;
		break;
	case TokenType.OpenBracket:
		ts.get();
		if (ts.peek.type == TokenType.CloseBracket) {
			// Dynamic array.
			auto end = match(ts, TokenType.CloseBracket);
			auto a = new ir.ArrayType();
			a.location = end.location - origin;
			a.base = base;
			base = a;
		} else if (ts.peek.type == TokenType.IntegerLiteral) {
			// Static array.
			auto integer = ts.get();
			auto end = match(ts, TokenType.CloseBracket);
			auto a = new ir.StaticArrayType();
			a.location = end.location - origin;
			a.base = base;
			a.length = to!int(integer.value);
			base = a;
		} else {
			// Associative array.
			auto a = new ir.AAType();
			a.value = base;
			a.key = parseType(ts);
			a.location = ts.peek.location - origin;
			match(ts, TokenType.CloseBracket);
			base = a;
		}
		break;
	default:
		break LOOP;
	}
	return base;
}

package ir.Type parsePrimitiveType(TokenStream ts)
{
	auto ptype = new ir.PrimitiveType();
	ptype.location = ts.peek.location;
	ptype.type = cast(ir.PrimitiveType.Kind) ts.peek.type;

	ts.get();
	return ptype;
}

ir.Function parseFunction(TokenStream ts, ir.Type base)
{
	auto fn = new ir.Function();
	fn.type = new ir.FunctionType();

	// <int> add(int a, int b) { }
	fn.type.ret = base;

	// int <add>(int a, int b) {}
	auto nameTok = match(ts, TokenType.Identifier);
	fn.name = nameTok.value;
	fn.location = nameTok.location;

	// int add<(int a, int b)> {}
	auto params = parseParameterList(ts, fn.type);
	foreach (i, param; params) {
		fn.type.params ~= param.type;
		auto p = new ir.FunctionParam();
		p.location = param.location;
		p.name = param.name;
		p.index = i;
		p.assign = param.assign;
		p.fn = fn;
		fn.params ~= p;
	}
	//fn.type.params = parseParameterList(ts, fn.type);
	fn.type.location = ts.previous.location - fn.type.ret.location;

	bool inBlocks = ts.peek.type != TokenType.Semicolon;
	while (inBlocks) {
		bool _in, _out;
		switch (ts.peek.type) {
		case TokenType.In:
			// <in> { }
			if (_in) {
				throw makeMultipleOutBlocks(ts.peek.location);
			}
			_in = true;
			match(ts, TokenType.In);
			fn.inContract = parseBlock(ts);
			break;
		case TokenType.Out:
			// <out>
			if (_out) {
				throw makeMultipleOutBlocks(ts.peek.location);
			}
			_out = true;
			match(ts, TokenType.Out);
			if (ts.peek.type == TokenType.OpenParen) {
				// out <(result)>
				match(ts, TokenType.OpenParen);
				auto identTok = match(ts, TokenType.Identifier);
				fn.outParameter = identTok.value;
				match(ts, TokenType.CloseParen);
			}
			fn.outContract = parseBlock(ts);
			break;
		case TokenType.OpenBrace:
		case TokenType.Body:
			if (ts.peek.type == TokenType.Body) {
				ts.get();
			}
			inBlocks = false;
			fn._body = parseBlock(ts);
			break;
		default:
			throw makeExpected(ts.peek.location, "block declaration");
		}
	}
	if (ts.peek.type == TokenType.Semicolon) {
		ts.get();
	}

	return fn;
}

ir.BlockStatement parseBlock(TokenStream ts)
{
	auto bs = new ir.BlockStatement();
	bs.location = ts.peek.location;

	match(ts, TokenType.OpenBrace);
	while (ts != TokenType.CloseBrace) {
		bs.statements ~= parseStatement(ts);
	}
	match(ts, TokenType.CloseBrace);

	return bs;
}

ir.EnumDeclaration parseEnumDeclaration(TokenStream ts)
{
	auto edecl = new ir.EnumDeclaration();
	edecl.location = ts.peek.location;

	auto nameTok = match(ts, TokenType.Identifier);
	edecl.name = nameTok.value;

	if (matchIf(ts, TokenType.Assign)) {
		edecl.assign = parseExp(ts);
	}

	return edecl;
}
