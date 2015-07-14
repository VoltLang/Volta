// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.declaration;

import watt.conv : toInt;
import watt.text.format : format;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.exceptions;
import volt.errors;

import volt.token.location;
import volt.parser.base;
import volt.parser.stream : Token, ParserStream;
import volt.parser.expression;
import volt.parser.toplevel;
import volt.parser.declaration;
import volt.parser.statements;


ir.Node[] parseVariable(ParserStream ps)
{
	if (ps.peek.type == TokenType.Alias) {
		return [parseAlias(ps)];
	}

	auto loc = ps.peek.location;
	auto _global = matchIf(ps, TokenType.Global);
	if (!_global) {
		_global = matchIf(ps, TokenType.Static);  // Deprecate after self-hosting etc.
	}

	ir.Type base = parseType(ps);
	if (ps.lookahead(1).type == TokenType.Comma ||
		ps.lookahead(1).type == TokenType.Semicolon ||
		ps.lookahead(1).type == TokenType.Assign) {
		// Normal declaration.
		if (_global) {
			throw makeUnexpected(loc, "global");
		}
		return reallyParseVariable(ps, base);
	} else if (ps.lookahead(1).type == TokenType.OpenParen) {
		// Function!
		auto fn = parseFunction(ps, base);
		fn.isGlobal = _global;
		return [fn];
	} else {
		throw makeExpected(ps.peek.location, "declaration");
	}
	version(Volt) assert(false);
}

ir.Variable[] parseJustVariable(ParserStream ps)
{
	ir.Type base = parseType(ps);
	ir.Node[] nodes = reallyParseVariable(ps, base);
	auto vars = new ir.Variable[](nodes.length);
	foreach (i, node; nodes) {
		vars[i] = cast(ir.Variable) node;
		assert(vars[i] !is null, "reallyParseVariable parsed non variable");
	}
	return vars;
}

ir.Alias parseAlias(ParserStream ps)
{
	auto a = new ir.Alias();
	a.location = ps.peek.location;

	match(ps, TokenType.Alias);
	auto nameTok = match(ps, TokenType.Identifier);
	a.name = nameTok.value;
	match(ps, TokenType.Assign);

	size_t pos = ps.save();

	size_t i = 1;
	bool bang;
	while (ps.lookahead(i).type != TokenType.Semicolon && ps.lookahead(i).type != TokenType.End) {
		bang = ps.lookahead(i).type == TokenType.Bang;
		if (bang) {
			break;
		}
		i++;
	}

	try {
		if (bang) {
			a.templateInstance = parseExp(ps);
		} else {
			a.id = parseQualifiedName(ps);
		}
		match(ps, TokenType.Semicolon);

	} catch (CompilerError e) {
		if (e.neverIgnore) {
			throw e;
		}
		ps.restore(pos);

		a.id = null;
		a.type = parseType(ps);
		match(ps, TokenType.Semicolon);
	}

	a.docComment = ps.comment();
	ps.retroComment = &a.docComment;
	return a;
}

ir.Node[] reallyParseVariable(ParserStream ps, ir.Type base)
{
	ir.Node[] decls;

	while (true) {
		auto d = new ir.Variable();
		d.location = ps.peek.location;
		d.docComment = ps.comment();
		d.type = base;
		auto nameTok = match(ps, TokenType.Identifier);
		d.name = nameTok.value;
		if (ps.peek.type == TokenType.Assign) {
			match(ps, TokenType.Assign);
			try {
				d.assign = parseExp(ps);
			} catch (CompilerError e) {
				version(Volt) {
					throw new CompilerError(e.location, e.message, e, true);
				} else {
					throw new CompilerError(e.location, e.msg, e, true);
				}
			}
		}
		decls ~= d;

		if (ps.peek.type == TokenType.Comma) {
			// Need to copy this on multiple.
			base = copyType(base);
			ps.get();
		} else {
			break;
		}
	}
	match(ps, TokenType.Semicolon);

	ps.retroComment = &decls[0].docComment;

	return decls;
}

ir.Type parseType(ParserStream ps)
{
	Location origin = ps.peek.location;

	ir.Type base;
	switch (ps.peek.type) {
	case TokenType.Void, TokenType.Char, TokenType.Byte, TokenType.Ubyte,
		 TokenType.Short, TokenType.Ushort, TokenType.Int, TokenType.Uint,
		 TokenType.Long, TokenType.Ulong, TokenType.Float, TokenType.Double,
		 TokenType.Real, TokenType.Bool, TokenType.Wchar, TokenType.Dchar:
		base = parsePrimitiveType(ps);
		break;
	case TokenType.Auto, TokenType.Const, TokenType.Immutable,
		 TokenType.Scope:
		base = parseStorageType(ps);
		break;
	case TokenType.Identifier, TokenType.Dot:
		base = parseTypeReference(ps);
		break;
	case TokenType.Typeof:
		base = parseTypeOf(ps);
		break;
	default:
		throw makeExpected(ps.peek.location, "primitive type");
	}

	base = parseTypeSigils(ps, origin, base);

	switch (ps.peek.type) {
	case TokenType.Function:
		base = parseFunctionType(ps, base);
		base.location = ps.peek.location - origin;
		base = parseTypeSigils(ps, origin, base);
		break;
	case TokenType.Delegate:
		base = parseDelegateType(ps, base);
		base.location = ps.peek.location - origin;
		base = parseTypeSigils(ps, origin, base);
		break;
	default:
		break;
	}

	base.location = ps.peek.location - origin;
	base.docComment = ps.comment();
	return base;
}

ir.TypeOf parseTypeOf(ParserStream ps)
{
	auto typeOf = new ir.TypeOf();
	typeOf.location = ps.peek.location;
	match(ps, TokenType.Typeof);
	match(ps, TokenType.OpenParen);
	typeOf.exp = parseExp(ps);
	match(ps, TokenType.CloseParen);
	return typeOf;
}

ir.TypeReference parseTypeReference(ParserStream ps)
{
	auto typeReference = new ir.TypeReference();
	typeReference.location = ps.peek.location;

	typeReference.id = parseQualifiedName(ps, true);

	assert(typeReference.id.identifiers.length > 0);
	typeReference.docComment = ps.comment();
	return typeReference;
}

ir.StorageType parseStorageType(ParserStream ps)
{
	auto storageType = new ir.StorageType();
	storageType.location = ps.peek.location;

	storageType.type = cast(ir.StorageType.Kind) ps.peek.type;
	ps.get();

	if (ps == [TokenType.Identifier, TokenType.Semicolon] ||
		ps == [TokenType.Identifier, TokenType.Assign, TokenType.Void, TokenType.Semicolon]) {
		throw makeCannotInfer(ps.peek.location);
	} else if (matchIf(ps, TokenType.OpenParen)) {
		storageType.base = parseType(ps);
		match(ps, TokenType.CloseParen);
	} else if (!(ps == [TokenType.Identifier, TokenType.Assign])) {
		storageType.base = parseType(ps);
	}

	storageType.docComment = ps.comment();
	return storageType;
}

ir.FunctionType parseFunctionType(ParserStream ps, ir.Type base)
{
	auto fn = new ir.FunctionType();
	fn.location = ps.peek.location;
	fn.docComment = ps.comment();

	fn.ret = base;
	match(ps, TokenType.Function);
	fn.params = parseParameterListFPtr(ps, fn);

	return fn;
}

ir.DelegateType parseDelegateType(ParserStream ps, ir.Type base)
{
	auto fn = new ir.DelegateType();
	fn.location = ps.peek.location;

	fn.ret = base;
	match(ps, TokenType.Delegate);
	fn.params = parseParameterListFPtr(ps, fn);

	fn.docComment = ps.comment();
	return fn;
}

ir.Type[] parseParameterListFPtr(ParserStream ps, ir.CallableType parentCallable)
{
	ir.Type[] types;

	match(ps, TokenType.OpenParen);
	while (ps.peek.type != TokenType.CloseParen) {
		if (matchIf(ps, TokenType.TripleDot)) {
			parentCallable.hasVarArgs = true;
			break;
		}
		auto var = parseParameter(ps);
		types ~= var.type;
		if (ps.peek.type == TokenType.Comma) {
			ps.get();
		}
	}
	match(ps, TokenType.CloseParen);

	return types;
}

ir.Variable[] parseParameterList(ParserStream ps, ir.CallableType parentCallable)
{
	ir.Variable[] vars;

	match(ps, TokenType.OpenParen);
	while (ps.peek.type != TokenType.CloseParen) {
		if (matchIf(ps, TokenType.TripleDot)) {
			if (parentCallable is null) {
				throw makeExpected(ps.peek.location, "function or delegate");
			}
			parentCallable.hasVarArgs = true;
			break;
		}
		auto var = parseParameter(ps);
		// foo(int a, int[] b...)
		if (matchIf(ps, TokenType.TripleDot)) {
			if (ps.peek.type != TokenType.CloseParen) {
				throw makeExpected(ps.peek.location, "homogenous variadic argument to be final argument");
			}
			parentCallable.hasVarArgs = false;
			parentCallable.homogenousVariadic = true;
		}
		vars ~= var;
		// foo(int a, int b, ...)
		if (ps.peek.type == TokenType.Comma) {
			ps.get();
			if (matchIf(ps, TokenType.TripleDot)) {
				if (ps.peek.type != TokenType.CloseParen) {
					throw makeExpected(ps.peek.location, "var args to be last argument");
				}
				parentCallable.hasVarArgs = true;
			}
		}
	}
	match(ps, TokenType.CloseParen);

	return vars;
}

ir.Variable parseParameter(ParserStream ps)
{
	ir.Variable p = new ir.Variable();
	p.storage = ir.Variable.Storage.Function;
	Location origin = ps.peek.location;

	/// @todo intermixed ref
	bool isOut, isIn, isRef;
	isRef = matchIf(ps, TokenType.Ref);
	if (!isRef) {
		isOut = matchIf(ps, TokenType.Out);
	}
	if (!isOut && !isRef) {
		isIn = matchIf(ps, TokenType.In);
	}

	p.type = parseType(ps);
	if (isRef || isOut) {
		auto s = new ir.StorageType();
		s.location = p.type.location;
		s.type = isRef ? ir.StorageType.Kind.Ref : ir.StorageType.Kind.Out;
		s.base = p.type;
		p.type = s;
	}
	if (isIn) {
		auto constStorage = buildStorageType(ps.peek.location, ir.StorageType.Kind.Const, p.type);
		auto scopeStorage = buildStorageType(ps.peek.location, ir.StorageType.Kind.Scope, constStorage);
		p.type = scopeStorage;
	}
	if (ps.peek.type == TokenType.Identifier) {
		Token name = match(ps, TokenType.Identifier);
		p.name = name.value;
		if (matchIf(ps, TokenType.Assign)) {
			p.assign = parseExp(ps);
		}
	} else if (ps.peek.type != TokenType.Comma && ps.peek.type != TokenType.CloseParen) {
		throw makeExpected(ps.peek.location, "',', ')', or an identifier", ps.peek.value);
	}
	p.location = ps.peek.location - origin;

	return p;
}

// Parse things that go on the end of types like * or []. If none, base is returned.
ir.Type parseTypeSigils(ParserStream ps, Location origin, ir.Type base)
{
	bool loop = true;
	while (loop) switch (ps.peek.type) {
	case TokenType.Asterix:
		auto end = ps.get();
		auto p = new ir.PointerType();
		p.location = end.location - origin;
		p.base = base;
		base = p;
		break;
	case TokenType.OpenBracket:
		ps.get();
		if (ps.peek.type == TokenType.CloseBracket) {
			// Dynamic array.
			auto end = match(ps, TokenType.CloseBracket);
			auto a = new ir.ArrayType();
			a.location = end.location - origin;
			a.base = base;
			base = a;
		} else if (ps.peek.type == TokenType.IntegerLiteral) {
			// Static array.
			auto integer = ps.get();
			auto end = match(ps, TokenType.CloseBracket);
			auto a = new ir.StaticArrayType();
			a.location = end.location - origin;
			a.base = base;
			a.length = cast(size_t)toInt(integer.value);
			base = a;
		} else {
			// Associative array.
			auto a = new ir.AAType();
			a.value = base;
			a.key = parseType(ps);
			a.location = ps.peek.location - origin;
			match(ps, TokenType.CloseBracket);
			base = a;
		}
		break;
	default:
		loop = false;
	}
	return base;
}

package ir.Type parsePrimitiveType(ParserStream ps)
{
	auto ptype = new ir.PrimitiveType();
	ptype.location = ps.peek.location;
	ptype.type = cast(ir.PrimitiveType.Kind) ps.peek.type;

	ps.get();
	return ptype;
}

ir.Function parseFunction(ParserStream ps, ir.Type base)
{
	auto fn = new ir.Function();
	fn.type = new ir.FunctionType();
	fn.docComment = base.docComment;
	ps.pushCommentLevel();
	scope (exit) ps.popCommentLevel();

	// <int> add(int a, int b) { }
	fn.type.ret = base;

	// int <add>(int a, int b) {}
	auto nameTok = match(ps, TokenType.Identifier);
	fn.name = nameTok.value;
	fn.location = nameTok.location;

	// int add<(int a, int b)> {}
	auto params = parseParameterList(ps, fn.type);
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
	//fn.type.params = parseParameterList(ps, fn.type);
	fn.type.location = ps.previous.location - fn.type.ret.location;

	bool inBlocks = ps.peek.type != TokenType.Semicolon;
	while (inBlocks) {
		bool _in, _out;
		switch (ps.peek.type) {
		case TokenType.In:
			// <in> { }
			if (_in) {
				throw makeMultipleOutBlocks(ps.peek.location);
			}
			_in = true;
			match(ps, TokenType.In);
			fn.inContract = parseBlock(ps);
			break;
		case TokenType.Out:
			// <out>
			if (_out) {
				throw makeMultipleOutBlocks(ps.peek.location);
			}
			_out = true;
			match(ps, TokenType.Out);
			if (ps.peek.type == TokenType.OpenParen) {
				// out <(result)>
				match(ps, TokenType.OpenParen);
				auto identTok = match(ps, TokenType.Identifier);
				fn.outParameter = identTok.value;
				match(ps, TokenType.CloseParen);
			}
			fn.outContract = parseBlock(ps);
			break;
		case TokenType.OpenBrace:
		case TokenType.Body:
			if (ps.peek.type == TokenType.Body) {
				ps.get();
			}
			inBlocks = false;
			fn._body = parseBlock(ps);
			break;
		default:
			throw makeExpected(ps.peek.location, "block declaration");
		}
	}
	if (ps.peek.type == TokenType.Semicolon) {
		ps.get();
	}

	return fn;
}

ir.BlockStatement parseBlock(ParserStream ps)
{
	auto bs = new ir.BlockStatement();
	bs.location = ps.peek.location;

	match(ps, TokenType.OpenBrace);
	eatComments(ps);
	while (ps != TokenType.CloseBrace) {
		eatComments(ps);
		bs.statements ~= parseStatement(ps);
	}
	match(ps, TokenType.CloseBrace);

	return bs;
}

ir.EnumDeclaration parseEnumDeclaration(ParserStream ps)
{
	auto edecl = new ir.EnumDeclaration();
	edecl.location = ps.peek.location;

	auto nameTok = match(ps, TokenType.Identifier);
	edecl.name = nameTok.value;

	if (matchIf(ps, TokenType.Assign)) {
		edecl.assign = parseExp(ps);
	}

	edecl.docComment = ps.comment();
	if (edecl.docComment.length == 0) {
		ps.retroComment = &edecl.docComment;
	}
	eatComments(ps);
	return edecl;
}
