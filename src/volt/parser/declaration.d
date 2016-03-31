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
import volt.parser.expression;
import volt.parser.toplevel;
import volt.parser.declaration;
import volt.parser.statements;


ParseStatus parseVariable(ParserStream ps, NodeSinkDg dg)
{
	if (ps == TokenType.Alias) {
		ir.Alias a;
		auto succeeded = parseAlias(ps, a);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Variable);
		}
		dg(a);
		return Succeeded;
	}

	auto loc = ps.peek.location;
	auto _global = matchIf(ps, TokenType.Global);
	if (!_global) {
		_global = matchIf(ps, TokenType.Static);  // Deprecate after self-hosting etc.
	}

	ir.Type base;
	auto succeeded = parseType(ps, base);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Variable);
	}
	if (ps.lookahead(1).type == TokenType.Comma ||
		ps.lookahead(1).type == TokenType.Semicolon ||
		ps.lookahead(1).type == TokenType.Assign) {
		// Normal declaration.
		if (_global) {
			return unexpectedToken(ps, ir.NodeType.Variable);
		}
		// No need to report variable here since its allready reported.
		return reallyParseVariable(ps, base, dg);
	} else if (ps.lookahead(1).type == TokenType.OpenParen) {
		// Function!
		ir.Function func;
		succeeded = parseFunction(ps, func, base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Variable);
		}
		if (_global && func.kind == ir.Function.Kind.Nested) {
			func.kind = ir.Function.Kind.GlobalNested;
		}
		dg(func);
		return Succeeded;
	} else {
		return parseExpected(ps, ps.peek.location, ir.NodeType.Variable, "declaration");
	}
	version (Volt) assert(false); // If
}

ParseStatus parseJustVariable(ParserStream ps, NodeSinkDg dg)
{
	ir.Type base;
	auto succeeded = parseType(ps, base);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Variable);
	}
	ir.Node[] nodes;
	// No need to report variable here since its allready reported.
	succeeded = reallyParseVariable(ps, base, dg);
	if (!succeeded) {
		return succeeded;
	}
	foreach (i, node; nodes) {
		dg(node);
		assert(cast(ir.Variable) node !is null, "reallyParseVariable parsed non variable");
	}
	return Succeeded;
}

ParseStatus parseAlias(ParserStream ps, out ir.Alias a)
{
	a = new ir.Alias();
	a.location = ps.peek.location;

	if (ps != [TokenType.Alias, TokenType.Identifier, TokenType.Assign]) {
		return unexpectedToken(ps, a);
	}
	ps.get();
	auto nameTok = ps.get();
	a.name = nameTok.value;
	ps.get();

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

	ParseStatus succeeded = Succeeded;
	do { // Poor mans goto.
		if (bang) {
			succeeded = parseExp(ps, a.templateInstance);
			if (!succeeded) {
				succeeded = unexpectedToken(ps, a);
				break;
			}
		} else {
			succeeded = parseQualifiedName(ps, a.id);
			if (!succeeded) {
				succeeded = parseFailed(ps, a);
				break;
			}
		}
		if (ps != TokenType.Semicolon) {
			succeeded = unexpectedToken(ps, a);
		} else {
			ps.get();
		}
	} while(false);

	if (!succeeded) {
		if (ps.neverIgnoreError) {
			return Failed;
		}
		ps.restore(pos);
		ps.resetErrors();

		a.id = null;
		if (ps == TokenType.Extern) {
			succeeded = parseAttribute(ps, a.externAttr, true);
			if (!succeeded) {
				return parseFailed(ps, a);
			}
		}
		succeeded = parseType(ps, a.type);
		if (!succeeded) {
			return parseFailed(ps, a);
		}
		succeeded = match(ps, a, TokenType.Semicolon);
		if (!succeeded) {
			return succeeded;
		}
	}

	a.docComment = ps.comment();
	ps.retroComment = a;
	return Succeeded;
}

ParseStatus reallyParseVariable(ParserStream ps, ir.Type base, NodeSinkDg dg)
{
	ir.Variable first;
	while (true) {
		auto d = new ir.Variable();
		d.location = ps.peek.location;
		d.docComment = ps.comment();
		d.type = base;
		Token nameTok;
		auto succeeded = match(ps, d, TokenType.Identifier, nameTok);
		if (!succeeded) {
			return succeeded;
		}
		d.name = nameTok.value;
		if (ps.peek.type == TokenType.Assign) {
			ps.get();
			succeeded = parseExp(ps, d.assign);
			if (!succeeded) {
				parseFailed(ps, d);
				ps.neverIgnoreError = true;
				return Failed;
			}
		}
		dg(d);

		if (first is null) {
			first = d;
		}

		if (ps.peek.type == TokenType.Comma) {
			// Need to copy this on multiple.
			base = copyType(base);
			ps.get();
		} else {
			break;
		}
	}
	auto succeeded = match(ps, ir.NodeType.Variable, TokenType.Semicolon);
	if (!succeeded) {
		return succeeded;
	}

	ps.retroComment = first;

	return Succeeded;
}

ParseStatus parseType(ParserStream ps, out ir.Type base)
{
	Location origin = ps.peek.location;

	switch (ps.peek.type) {
	case TokenType.Void, TokenType.Char, TokenType.Byte, TokenType.Ubyte,
		 TokenType.Short, TokenType.Ushort, TokenType.Int, TokenType.Uint,
		 TokenType.Long, TokenType.Ulong, TokenType.Float, TokenType.Double,
		 TokenType.Real, TokenType.Bool, TokenType.Wchar, TokenType.Dchar:
		base = parsePrimitiveType(ps);
		break;
	case TokenType.Auto, TokenType.Const, TokenType.Immutable,
		 TokenType.Scope:
		ir.StorageType st;
		auto succeeded = parseStorageType(ps, st);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.StorageType);
		}
		base = st;
		break;
	case TokenType.Identifier, TokenType.Dot:
		ir.TypeReference tr;
		auto succeeded = parseTypeReference(ps, tr);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TypeOf);
		}
		base = tr;
		break;
	case TokenType.Typeof:
		ir.TypeOf t;
		auto succeeded = parseTypeOf(ps, t);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TypeOf);
		}
		base = t;
		break;
	default:
		return parseExpected(ps, ps.peek.location, ir.NodeType.Invalid, "primitive type");
	}

	ir.Type tmp;
	auto succeeded = parseTypeSigils(ps, tmp, origin, base);
	if (!succeeded) {
		parseFailed(ps, ir.NodeType.Function);
	}
	base = tmp;

	switch (ps.peek.type) {
	case TokenType.Function:
		ir.FunctionType func;
		succeeded = parseFunctionType(ps, func, base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Function);
		}
		base = func;
		base.location = ps.peek.location - origin;
		succeeded = parseTypeSigils(ps, tmp, origin, base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Function);
		}
		base = tmp;
		break;
	case TokenType.Delegate:
		ir.DelegateType func;
		succeeded = parseDelegateType(ps, func, base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Function);
		}
		base = func;
		base.location = ps.peek.location - origin;
		succeeded = parseTypeSigils(ps, tmp, origin, base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Function);
		}
		base = tmp;
		break;
	default:
		break;
	}

	base.location = ps.peek.location - origin;
	base.docComment = ps.comment();
	return Succeeded;
}

ParseStatus parseTypeOf(ParserStream ps, out ir.TypeOf typeOf)
{
	typeOf = new ir.TypeOf();
	typeOf.location = ps.peek.location;
	if (ps != [TokenType.Typeof, TokenType.OpenParen]) {
		return parseFailed(ps, typeOf);
	}
	ps.get();
	ps.get();
	auto succeeded = parseExp(ps, typeOf.exp);
	if (!succeeded) {
		return parseFailed(ps, typeOf);
	}
	if (ps != TokenType.CloseParen) {
		return unexpectedToken(ps, typeOf);
	}
	ps.get();
	return Succeeded;
}

ParseStatus parseTypeReference(ParserStream ps, out ir.TypeReference typeReference)
{
	typeReference = new ir.TypeReference();
	typeReference.location = ps.peek.location;

	auto succeeded = parseQualifiedName(ps, typeReference.id, true);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.TypeReference);
	}

	assert(typeReference.id.identifiers.length > 0);
	typeReference.docComment = ps.comment();
	return Succeeded;
}

ParseStatus parseStorageType(ParserStream ps, out ir.StorageType storageType)
{
	storageType = new ir.StorageType();
	storageType.location = ps.peek.location;

	storageType.type = cast(ir.StorageType.Kind) ps.peek.type;
	ps.get();

	if (ps == [TokenType.Identifier, TokenType.Semicolon] ||
		ps == [TokenType.Identifier, TokenType.Assign, TokenType.Void, TokenType.Semicolon]) {
		parseExpected(ps, ps.peek.location, storageType, "explicit type");
		ps.neverIgnoreError = true;
		return Failed;
	} else if (matchIf(ps, TokenType.OpenParen)) {
		auto succeeded = parseType(ps, storageType.base);
		if (!succeeded) {
			return parseFailed(ps, storageType);
		}
		succeeded = match(ps, storageType, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
	} else if (!(ps == [TokenType.Identifier, TokenType.Assign])) {
		auto succeeded = parseType(ps, storageType.base);
		if (!succeeded) {
			return parseFailed(ps, storageType);
		}
	}

	storageType.docComment = ps.comment();
	return Succeeded;
}

ParseStatus parseFunctionType(ParserStream ps, out ir.FunctionType func, ir.Type base)
{
	func = new ir.FunctionType();
	func.location = ps.peek.location;
	func.docComment = ps.comment();

	func.ret = base;
	auto succeeded = match(ps, func, TokenType.Function);
	if (!succeeded) {
		return succeeded;
	}
	succeeded = parseParameterListFPtr(ps, func.params, func);
	if (!succeeded) {
		return parseFailed(ps, func);
	}
	func.isArgRef = new bool[](func.params.length);
	func.isArgOut = new bool[](func.params.length);

	return Succeeded;
}

ParseStatus parseDelegateType(ParserStream ps, out ir.DelegateType func, ir.Type base)
{
	func = new ir.DelegateType();
	func.location = ps.peek.location;

	func.ret = base;
	auto succeeded = match(ps, func, TokenType.Delegate);
	if (!succeeded) {
		return succeeded;
	}
	succeeded = parseParameterListFPtr(ps, func.params, func);
	if (!succeeded) {
		return parseFailed(ps, func);
	}
	func.isArgRef = new bool[](func.params.length);
	func.isArgOut = new bool[](func.params.length);

	func.docComment = ps.comment();
	return Succeeded;
}

ParseStatus parseParameterListFPtr(ParserStream ps, out ir.Type[] types, ir.CallableType parentCallable)
{
	auto succeeded = match(ps, ir.NodeType.Variable, TokenType.OpenParen);
	if (!succeeded) {
		return succeeded;
	}
	while (ps.peek.type != TokenType.CloseParen) {
		if (matchIf(ps, TokenType.TripleDot)) {
			parentCallable.hasVarArgs = true;
			break;
		}
		ir.Variable var;
		succeeded = parseParameter(ps, var);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Variable);
		}
		types ~= var.type;
		matchIf(ps, TokenType.Comma);
	}
	return match(ps, ir.NodeType.Variable, TokenType.CloseParen);
}

ParseStatus parseParameterList(ParserStream ps, out ir.Variable[] vars, ir.CallableType parentCallable)
{
	auto succeeded = match(ps, ir.NodeType.Function, TokenType.OpenParen);
	if (!succeeded) {
		return succeeded;
	}
	while (ps.peek.type != TokenType.CloseParen) {
		if (matchIf(ps, TokenType.TripleDot)) {
			if (parentCallable is null) {
				return unexpectedToken(ps, ir.NodeType.Function);
			}
			parentCallable.hasVarArgs = true;
			break;
		}
		ir.Variable var;
		succeeded = parseParameter(ps, var);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Function);
		}
		// foo(int a, int[] b...)
		if (matchIf(ps, TokenType.TripleDot)) {
			if (ps.peek.type != TokenType.CloseParen) {
				return parseExpected(ps, ps.peek.location, ir.NodeType.Function, 
				                     "homogenous variadic argument to be final argument");
			}
			parentCallable.hasVarArgs = false;
			parentCallable.homogenousVariadic = true;
		}
		vars ~= var;
		// foo(int a, int b, ...)
		if (matchIf(ps, TokenType.Comma)) {
			if (matchIf(ps, TokenType.TripleDot)) {
				if (ps.peek.type != TokenType.CloseParen) {
					return parseExpected(ps, ps.peek.location, ir.NodeType.Function,
					                     "varargs to be final argument");
				}
				parentCallable.hasVarArgs = true;
			}
		}
	}
	return match(ps, ir.NodeType.Function, TokenType.CloseParen);
}

ParseStatus parseParameter(ParserStream ps, out ir.Variable p)
{
	p = new ir.Variable();
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

	auto succeeded = parseType(ps, p.type);
	if (!succeeded) {
		return parseFailed(ps, p);
	}
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
		Token name = ps.get();
		p.name = name.value;
		if (matchIf(ps, TokenType.Assign)) {
			succeeded = parseExp(ps, p.assign);
			if (!succeeded) {
				return parseFailed(ps, p);
			}
		}
	} else if (ps.peek.type != TokenType.Comma && ps.peek.type != TokenType.CloseParen) {
		return parseExpected(ps, ps.peek.location, p, "',', ')', or an identifier");
	}
	p.location = ps.peek.location - origin;

	return Succeeded;
}

// Parse things that go on the end of types like * or []. If none, base is returned.
ParseStatus parseTypeSigils(ParserStream ps, out ir.Type outType, Location origin, ir.Type base)
{
	outType = base;
	bool loop = true;
	while (loop) switch (ps.peek.type) {
	case TokenType.Asterix:
		auto end = ps.get();
		auto p = new ir.PointerType();
		p.location = end.location - origin;
		p.base = outType;
		outType = p;
		break;
	case TokenType.OpenBracket:
		ps.get();
		if (ps.peek.type == TokenType.CloseBracket) {
			// Dynamic array.
			auto end = ps.get();
			auto a = new ir.ArrayType();
			a.location = end.location - origin;
			a.base = outType;
			outType = a;
		} else if (ps.peek.type == TokenType.IntegerLiteral) {
			// Static array.
			auto integer = ps.get();
			Token end;
			auto succeeded = match(ps, outType, TokenType.CloseBracket, end);
			if (!succeeded) {
				return succeeded;
			}
			auto a = new ir.StaticArrayType();
			a.location = end.location - origin;
			a.base = outType;
			a.length = cast(size_t)toInt(integer.value);
			outType = a;
		} else {
			// Associative array.
			auto a = new ir.AAType();
			a.value = base;
			auto succeeded = parseType(ps, a.key);
			if (!succeeded) {
				return parseFailed(ps, outType);
			}
			a.location = ps.peek.location - origin;
			succeeded = match(ps, outType, TokenType.CloseBracket);
			if (!succeeded) {
				return succeeded;
			}
			outType = a;
		}
		break;
	default:
		loop = false;
	}
	return Succeeded;
}

ir.Type parsePrimitiveType(ParserStream ps)
{
	auto ptype = new ir.PrimitiveType();
	ptype.location = ps.peek.location;
	ptype.type = cast(ir.PrimitiveType.Kind) ps.peek.type;

	ps.get();
	return ptype;
}

ParseStatus parseFunction(ParserStream ps, out ir.Function func, ir.Type base)
{
	func = new ir.Function();
	func.type = new ir.FunctionType();
	func.docComment = base.docComment;
	ps.functionDepth++;
	ps.pushCommentLevel();
	scope (success) {
		if (ps.functionDepth > 1 && func !is null) {
			func.kind = ir.Function.Kind.Nested;
		}
		ps.functionDepth--;
		ps.popCommentLevel();
	}

	// <int> add(int a, int b) { }
	func.type.ret = base;

	// int <add>(int a, int b) {}
	Token nameTok;
	auto succeeded = match(ps, func, TokenType.Identifier, nameTok);
	if (!succeeded) {
		return succeeded;
	}
	func.name = nameTok.value;
	func.location = nameTok.location;

	// int add<(int a, int b)> {}
	ir.Variable[] params;
	succeeded = parseParameterList(ps, params, func.type);
	if (!succeeded) {
		return parseFailed(ps, func);
	}
	foreach (i, param; params) {
		func.type.params ~= param.type;
		func.type.isArgRef ~= false;
		func.type.isArgOut ~= false;
		auto p = new ir.FunctionParam();
		p.location = param.location;
		p.name = param.name;
		p.index = i;
		p.assign = param.assign;
		p.func = func;
		func.params ~= p;
	}
	//func.type.params = parseParameterList(ps, func.type);
	func.type.location = ps.previous.location - func.type.ret.location;

	bool inBlocks = ps.peek.type != TokenType.Semicolon;
	while (inBlocks) {
		bool _in, _out;
		switch (ps.peek.type) {
		case TokenType.In:
			ps.get();
			// <in> { }
			if (_in) {
				return parseExpected(ps, ps.peek.location, func, "only one in block");
			}
			_in = true;
			succeeded = parseBlock(ps, func.inContract);
			if (!succeeded) {
				return parseFailed(ps, func);
			}
			break;
		case TokenType.Out:
			ps.get();
			// <out>
			if (_out) {
				return parseExpected(ps, ps.peek.location, func, "only one out block");
			}
			_out = true;
			if (ps.peek.type == TokenType.OpenParen) {
				ps.get();
				// out <(result)>
				if (ps != [TokenType.Identifier, TokenType.CloseParen]) {
					return unexpectedToken(ps, func);
				}
				auto identTok = ps.get();
				func.outParameter = identTok.value;
				ps.get();
			}
			succeeded = parseBlock(ps, func.outContract);
			if (!succeeded) {
				return parseFailed(ps, func);
			}
			break;
		case TokenType.OpenBrace:
		case TokenType.Body:
			if (ps.peek.type == TokenType.Body) {
				ps.get();
			}
			inBlocks = false;
			succeeded = parseBlock(ps, func._body);
			if (!succeeded) {
				return parseFailed(ps, func);
			}
			break;
		default:
			return parseExpected(ps, ps.peek.location, func, "block declaration");
		}
	}
	matchIf(ps, TokenType.Semicolon);

	return Succeeded;
}

/**
 * This parses a function block, different from BlockStatement.
 *
 * void func()
 * out (result) <{ ... }>
 * in <{ ... }>
 * body <{ ... }>
 */
ParseStatus parseBlock(ParserStream ps, out ir.BlockStatement bs)
{
	bs = new ir.BlockStatement();
	bs.location = ps.peek.location;

	auto succeeded = match(ps, bs, TokenType.OpenBrace);
	if (!succeeded) {
		return succeeded;
	}

	succeeded = eatComments(ps);
	if (!succeeded) {
		return succeeded;
	}
	auto sink = new NodeSink();
	while (ps != TokenType.CloseBrace) {
		succeeded = eatComments(ps);
		if (!succeeded) {
			return succeeded;
		}
		succeeded = parseStatement(ps, sink.push);
		if (!succeeded) {
			return parseFailed(ps, bs);
		}
	}
	bs.statements = sink.array;
	return match(ps, bs, TokenType.CloseBrace);
}

ParseStatus parseEnumDeclaration(ParserStream ps, out ir.EnumDeclaration edecl)
{
	edecl = new ir.EnumDeclaration();
	edecl.location = ps.peek.location;

	Token nameTok;
	auto succeeded = match(ps, edecl, TokenType.Identifier, nameTok);
	if (!succeeded) {
		return succeeded;
	}
	edecl.name = nameTok.value;

	if (matchIf(ps, TokenType.Assign)) {
		succeeded = parseExp(ps, edecl.assign);
		if (!succeeded) {
			return parseFailed(ps, edecl);
		}
	}

	edecl.docComment = ps.comment();
	if (edecl.docComment.length == 0) {
		ps.retroComment = edecl;
	}
	return eatComments(ps);
}
