/*#D*/
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.parser.declaration;

import watt.conv : toInt;
import watt.text.format : format;

import ir = volta.ir;
import volta.util.util;
import volta.util.copy;
import volta.util.string;
import volta.token.writer;

import volta.errors;
import volta.ir.token : isPrimitiveTypeToken, isStorageTypeToken;
import volta.ir.location;
import volta.parser.base;
import volta.parser.expression;
import volta.parser.toplevel;
import volta.parser.declaration;
import volta.parser.statements;
import volta.parser.templates;


ParseStatus parseVariable(ParserStream ps, NodeSinkDg dgt)
{
	if (ps == TokenType.Alias) {
		if (ps.magicFlagD && isTemplateInstance(ps)) {
			ir.TemplateInstance ti;
			parseLegacyTemplateInstance(ps, /*#out*/ti);
			dgt(ti);
			return Succeeded;
		}
		ir.Alias a;
		auto succeeded = parseAlias(ps, /*#out*/a);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Variable);
		}
		dgt(a);
		return Succeeded;
	}

	auto loc = ps.peek.loc;
	auto _global = matchIf(ps, TokenType.Global);
	if (!_global) {
		// Deprecate after self-hosting etc.
		_global = matchIf(ps, TokenType.Static);  
	}

	if (ps == TokenType.Fn) {
		if (isTemplateInstance(ps)) {
			ir.TemplateInstance ti;
			auto succeeded = parseTemplateInstance(ps, /*#out*/ti);
			if (succeeded) {
				dgt(ti);
			}
		} else if (isTemplateDefinition(ps)) {
			ir.TemplateDefinition td;
			auto succeeded = parseTemplateDefinition(ps, /*#out*/td);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Variable);
			}
			dgt(td);
		} else {
			ir.Function func;
			auto succeeded = parseNewFunction(ps, /*#out*/func);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Variable);
			}
			if (_global && func.kind == ir.Function.Kind.Invalid) {
				func.kind = ir.Function.Kind.GlobalNested;
			}
			dgt(func);
		}
		return Succeeded;
	}

	bool colonDeclaration = isColonDeclaration(ps);

	ir.Type base;
	if (!colonDeclaration) {
		auto succeeded = parseType(ps, /*#out*/base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Variable);
		}
	}

	bool eof;
	if (!colonDeclaration && (ps.lookahead(1, /*#out*/eof).type == TokenType.Comma ||
		ps.lookahead(1, /*#out*/eof).type == TokenType.Semicolon ||
		ps.lookahead(1, /*#out*/eof).type == TokenType.Assign)) {
		// Normal declaration.
		if (_global) {
			return unexpectedToken(ps, ir.NodeType.Variable);
		}
		// No need to report variable here since it's already reported.
		return reallyParseVariable(ps, base, dgt);
	} else if (colonDeclaration) {
		// New variable declaration.
		return parseColonAssign(ps, dgt);
	} else if (ps.lookahead(1, /*#out*/eof).type == TokenType.OpenParen) {
		// Function!
		ir.Function func;
		auto succeeded = parseFunction(ps, /*#out*/func, base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Variable);
		}
		if (_global && func.kind == ir.Function.Kind.Invalid) {
			func.kind = ir.Function.Kind.GlobalNested;
		}
		warningOldStyleFunction(/*#ref*/func.loc, ps.magicFlagD, ps.settings);
		dgt(func);
		return Succeeded;
	} else {
		return parseExpected(ps, /*#ref*/ps.peek.loc, ir.NodeType.Variable, "declaration");
	}
}

ParseStatus parseJustVariable(ParserStream ps, NodeSinkDg dgt)
{
	ir.Type base;
	auto succeeded = parseType(ps, /*#out*/base);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Variable);
	}
	ir.Node[] nodes;
	// No need to report variable here since it's already reported.
	succeeded = reallyParseVariable(ps, base, dgt);
	if (!succeeded) {
		return succeeded;
	}
	foreach (i, node; nodes) {
		dgt(node);
		assert(cast(ir.Variable) node !is null, "reallyParseVariable parsed non variable");
	}
	return Succeeded;
}

ParseStatus parseAlias(ParserStream ps, out ir.Alias a)
{
	a = new ir.Alias();
	a.loc = ps.peek.loc;
	a.docComment = ps.comment();

	if (ps != [TokenType.Alias, TokenType.Identifier, TokenType.Assign]) {
		return unexpectedToken(ps, a);
	}
	ps.get();
	auto nameTok = ps.get();
	a.name = nameTok.value;
	ps.get();

	size_t pos = ps.save();

	size_t i = 1;
	bool bang, eof;
	while (ps.lookahead(i, /*#out*/eof).type != TokenType.Semicolon && !ps.eofIndex(i)) {
		bang = ps.lookahead(i, /*#out*/eof).type == TokenType.Bang;
		if (bang) {
			break;
		}
		i++;
	}

	ParseStatus succeeded = Succeeded;
	do { // Poor mans goto.
		if (bang) {
			succeeded = parseExp(ps, /*#out*/a.templateInstance);
			if (!succeeded) {
				succeeded = unexpectedToken(ps, a);
				break;
			}
		} else {
			succeeded = parseQualifiedName(ps, /*#out*/a.id);
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

		if (ps == TokenType.Static) {
			succeeded = parseAliasStaticIf(ps, /*#out*/a.staticIf);
			if (!succeeded) {
				return parseFailed(ps, a);
			}
			ps.retroComment = a;
			return Succeeded;
		}

		if (ps == TokenType.Extern) {
			succeeded = parseAttribute(ps, /*#out*/a.externAttr, true);
			if (!succeeded) {
				return parseFailed(ps, a);
			}
		}
		succeeded = parseType(ps, /*#out*/a.type);
		if (!succeeded) {
			return parseFailed(ps, a);
		}
		succeeded = match(ps, a, TokenType.Semicolon);
		if (!succeeded) {
			return succeeded;
		}
	}

	ps.retroComment = a;
	return Succeeded;
}

ParseStatus parseAliasStaticIf(ParserStream ps, out ir.AliasStaticIf asi)
{
	asi = new ir.AliasStaticIf();
	asi.loc = ps.peek.loc;

	auto succeeded = match(ps, asi.nodeType,
		[TokenType.Static, TokenType.If, TokenType.OpenParen]);
	if (!succeeded) {
		return succeeded;
	}

	do {
		ir.Exp condition;
		succeeded = parseExp(ps, /*#out*/condition);
		if (!succeeded) {
			return parseFailed(ps, asi.nodeType);
		}
		succeeded = match(ps, asi.nodeType,
			[TokenType.CloseParen, TokenType.OpenBrace]);
		if (!succeeded) {
			return succeeded;
		}

		ir.Type type;
		succeeded = parseType(ps, /*#out*/type);
		if (!succeeded) {
			return parseFailed(ps, asi.nodeType);
		}
		succeeded = match(ps, asi.nodeType,
			[TokenType.Semicolon, TokenType.CloseBrace]);
		if (!succeeded) {
			return parseFailed(ps, asi.nodeType);
		}

		asi.conditions ~= condition;
		asi.types ~= type;
		if (ps != TokenType.Else || ps == [TokenType.Else, TokenType.OpenBrace]) {
			break;
		}
		succeeded = match(ps, asi.nodeType,
			[TokenType.Else, TokenType.If, TokenType.OpenParen]);
		if (!succeeded) {
			return succeeded;
		}
	} while (!ps.eof);

	if (ps == TokenType.Else) {
		succeeded = match(ps, asi.nodeType,
			[TokenType.Else, TokenType.OpenBrace]);
		ir.Type type;
		succeeded = parseType(ps, /*#out*/type);
		if (!succeeded) {
			return parseFailed(ps, asi.nodeType);
		}
		succeeded = match(ps, asi.nodeType,
			[TokenType.Semicolon, TokenType.CloseBrace]);
		if (!succeeded) {
			return succeeded;
		}
		asi.types ~= type;
	}

	return Succeeded;
}

ParseStatus reallyParseVariable(ParserStream ps, ir.Type base, NodeSinkDg dgt)
{
	ir.Variable first;
	while (true) {
		auto d = new ir.Variable();
		d.loc = ps.peek.loc;
		d.docComment = ps.comment();
		d.type = base;
		Token nameTok;
		auto succeeded = match(ps, d, TokenType.Identifier, /*#out*/nameTok);
		if (!succeeded) {
			/* TODO: Figure out precisely what needs continuing,
			 * and only ignore that.
			 */
			ps.neverIgnoreError = ps == TokenType.Fn;
			return succeeded;
		}
		d.name = nameTok.value;
		if (ps.peek.type == TokenType.Assign) {
			ps.get();
			succeeded = parseExp(ps, /*#out*/d.assign);
			if (!succeeded) {
				parseFailed(ps, d);
				ps.neverIgnoreError = true;
				return Failed;
			}
		}
		warningOldStyleVariable(/*#ref*/d.loc, ps.magicFlagD, ps.settings);
		dgt(d);

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
	Location origin = ps.peek.loc;
	auto dcomment = ps.comment();

	switch (ps.peek.type) {
	case TokenType.Void, TokenType.Char, TokenType.Byte, TokenType.Ubyte,
		 TokenType.Short, TokenType.Ushort, TokenType.Int, TokenType.Uint,
		 TokenType.Long, TokenType.Ulong, TokenType.Float, TokenType.Double,
		 TokenType.Real, TokenType.Bool, TokenType.Wchar, TokenType.Dchar,
		 TokenType.I8, TokenType.I16, TokenType.I32, TokenType.I64,
		 TokenType.U8, TokenType.U16, TokenType.U32, TokenType.U64,
		 TokenType.F32, TokenType.F64:
		base = parsePrimitiveType(ps);
		break;
	case TokenType.Auto, TokenType.Const, TokenType.Immutable,
		 TokenType.Scope:
		ir.StorageType st;
		auto succeeded = parseStorageType(ps, /*#out*/st);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.StorageType);
		}
		base = st;
		break;
	case TokenType.Identifier, TokenType.Dot:
		ir.TypeReference tr;
		auto succeeded = parseTypeReference(ps, /*#out*/tr);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TypeOf);
		}
		base = tr;
		break;
	case TokenType.Typeof:
		ir.TypeOf t;
		auto succeeded = parseTypeOf(ps, /*#out*/t);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TypeOf);
		}
		base = t;
		break;
	case TokenType.Fn:
	case TokenType.Dg:
		ir.CallableType func;
		auto succeeded = parseNewFunctionType(ps, /*#out*/func);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TypeOf);
		}
		base = func;
		break;
	case TokenType.OpenParen:
		ps.get();
		auto succeeded = parseType(ps, /*#out*/base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TypeOf);
		}
		auto retval = match(ps, base, TokenType.CloseParen);
		if (retval != Succeeded) {
			return retval;
		}
		break;
	default:
		return parseExpected(ps, /*#ref*/ps.peek.loc, ir.NodeType.Invalid, "primitive type");
	}

	ir.Type tmp;
	auto succeeded = parseTypeSigils(ps, /*#out*/tmp, origin, base);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Function);
	}
	base = tmp;

	switch (ps.peek.type) {
	case TokenType.Function:
		ir.FunctionType func;
		succeeded = parseFunctionType(ps, /*#out*/func, base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Function);
		}
		base = func;
		base.loc = ps.peek.loc - origin;
		succeeded = parseTypeSigils(ps, /*#out*/tmp, origin, base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Function);
		}
		base = tmp;
		break;
	case TokenType.Delegate:
		ir.DelegateType func;
		succeeded = parseDelegateType(ps, /*#out*/func, base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Function);
		}
		base = func;
		base.loc = ps.peek.loc - origin;
		succeeded = parseTypeSigils(ps, /*#out*/tmp, origin, base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Function);
		}
		base = tmp;
		break;
	default:
		break;
	}

	base.loc = ps.peek.loc - origin;
	base.docComment = dcomment;
	return Succeeded;
}

ParseStatus parseTypeOf(ParserStream ps, out ir.TypeOf typeOf)
{
	typeOf = new ir.TypeOf();
	typeOf.loc = ps.peek.loc;
	if (ps != [TokenType.Typeof, TokenType.OpenParen]) {
		return parseFailed(ps, typeOf);
	}
	ps.get();
	ps.get();
	auto succeeded = parseExp(ps, /*#out*/typeOf.exp);
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
	typeReference.loc = ps.peek.loc;

	auto succeeded = parseQualifiedName(ps, /*#out*/typeReference.id, true);
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
	storageType.loc = ps.peek.loc;

	storageType.type = cast(ir.StorageType.Kind) ps.peek.type;
	ps.get();

	if (ps == [TokenType.Identifier, TokenType.Semicolon] ||
		ps == [TokenType.Identifier, TokenType.Assign, TokenType.Void, TokenType.Semicolon]) {
		parseExpected(ps, /*#ref*/ps.peek.loc, storageType, "explicit type");
		ps.neverIgnoreError = true;
		return Failed;
	} else if (matchIf(ps, TokenType.OpenParen)) {
		auto succeeded = parseType(ps, /*#out*/storageType.base);
		if (!succeeded) {
			return parseFailed(ps, storageType);
		}
		succeeded = match(ps, storageType, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
	} else {
		bool autoDecl = (ps == [TokenType.Identifier, TokenType.Assign]) != 0;
		size_t i = 1;
		int parenDepth;
		bool eof;
		while (autoDecl && !eof) {
			if (ps.lookahead(i, /*#out*/eof).type == TokenType.OpenParen) {
				parenDepth++;
			}
			if (ps.lookahead(i, /*#out*/eof).type == TokenType.CloseParen) {
				parenDepth--;
			}
			if (parenDepth < 0) {
				autoDecl = false;
			}
			if (ps.lookahead(i, /*#out*/eof).type == TokenType.Semicolon) {
				break;
			}
			i++;
		}
		if (!autoDecl) {
			auto succeeded = parseType(ps, /*#out*/storageType.base);
			if (!succeeded) {
				return parseFailed(ps, storageType);
			}
		}
	}

	storageType.docComment = ps.comment();
	return Succeeded;
}

ParseStatus parseNewFunctionParams(ParserStream ps, ir.CallableType func)
{
	auto succeeded = match(ps, func, TokenType.OpenParen);
	if (!succeeded) {
		return succeeded;
	}

	auto matchedComma = false;
	while (ps != TokenType.CloseParen) {
		matchedComma = false;
		if (matchIf(ps, TokenType.TripleDot)) {
			func.hasVarArgs = true;
			break;
		}
		bool argRef, argOut, argIn;
		while (ps == TokenType.Out || ps == TokenType.In || ps == TokenType.Ref) {
			auto targRef = matchIf(ps, TokenType.Ref);
			if (targRef && argRef) {
				return parseFailed(ps, func);
			}
			argRef = targRef;
			auto targOut = matchIf(ps, TokenType.Out);
			if (targOut && argOut) {
				return parseFailed(ps, func);
			}
			argOut = targOut;
			auto targIn = matchIf(ps, TokenType.In);
			if (targIn && argIn) {
				return parseFailed(ps, func);
			}
			argIn = targIn;
		}
		int roi = (argRef ? 1 : 0) + (argOut ? 1 : 0) + (argIn ? 1 : 0);
		if (roi > 1) {
			return parseFailed(ps, func);
		}
		if (ps == [TokenType.Identifier, TokenType.Colon]) {
			match(ps, func, TokenType.Identifier);
			match(ps, func, TokenType.Colon);
		}
		ir.Type t;
		succeeded = parseType(ps, /*#out*/t);
		if (!succeeded) {
			return parseFailed(ps, func);
		}
		if (argRef || argOut) {
			auto s = new ir.StorageType();
			s.loc = t.loc;
			s.type = argRef ? ir.StorageType.Kind.Ref : ir.StorageType.Kind.Out;
			s.base = t;
			t = s;
		}
		if (argIn) {
			auto constStorage = buildStorageType(/*#ref*/t.loc, ir.StorageType.Kind.Const, t);
			auto scopeStorage = buildStorageType(/*#ref*/t.loc, ir.StorageType.Kind.Scope, constStorage);
			t = scopeStorage;
		}
		func.params ~= t;
		matchedComma = matchIf(ps, TokenType.Comma);
	}

	if (matchedComma) {
		return parseExpected(ps, /*#ref*/ps.peek.loc, func,
			"parameter list's closing ')' character, not ','");
	}

	succeeded = match(ps, func, TokenType.CloseParen);
	if (!succeeded) {
		return succeeded;
	}

	return Succeeded;
}

ParseStatus parseNewFunctionType(ParserStream ps, out ir.CallableType func)
{
	if (matchIf(ps, TokenType.Fn)) {
		func = new ir.FunctionType();
	} else if (matchIf(ps, TokenType.Dg)) {
		func = new ir.DelegateType();
	} else {
		return parseFailed(ps, ir.NodeType.FunctionType);
	}
	func.loc = ps.peek.loc;
	func.docComment = ps.comment();

	func.linkage = ir.Linkage.Volt;
	if (matchIf(ps, TokenType.Bang)) {
		auto linkageName = ps.peek.value;
		auto succeeded = match(ps, func, TokenType.Identifier);
		if (!succeeded) {
			return succeeded;
		}
		if (linkageName == "C" && matchIf(ps, TokenType.DoublePlus)) {
			func.linkage = ir.Linkage.CPlusPlus;
		} else switch (linkageName) {
		case "C": func.linkage = ir.Linkage.C; break;
		case "Volt": func.linkage = ir.Linkage.Volt; break;
		case "D": func.linkage = ir.Linkage.D; break;
		case "Windows": func.linkage = ir.Linkage.Windows; break;
		case "Pascal": func.linkage = ir.Linkage.Pascal; break;
		case "System": func.linkage = ir.Linkage.System; break;
		default:
			return parseExpected(ps, /*#ref*/ps.peek.loc, func,
			                     "Volt, C, C++, D, Windows, Pascal, or System linkage");
		}
	}

	auto succeeded = parseNewFunctionParams(ps, func);
	if (!succeeded) {
		return parseFailed(ps, func);
	}
	func.isArgRef = new bool[](func.params.length);
	func.isArgOut = new bool[](func.params.length);

	bool parenRet = matchIf(ps, TokenType.OpenParen);

	auto mark = ps.save();

	if (!parenRet || ps != TokenType.CloseParen) {
		succeeded = parseType(ps, /*#out*/func.ret);
		if (!succeeded) {
			func.ret = buildVoid(/*#ref*/func.loc);
			ps.restore(mark);
			ps.resetErrors();
		}
	}
	if (func.ret is null) {
		panic(ps.errSink, func, "null func ret");
		assert(false);
	}

	if (parenRet && ps == TokenType.Comma) {
		// TODO: Parse multiple return types here.
		return parseFailed(ps, func);
	}

	if (parenRet) {
		succeeded = match(ps, func, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
	}

	return Succeeded;
}

ParseStatus parseFunctionType(ParserStream ps, out ir.FunctionType func, ir.Type base)
{
	warningOldStyleFunctionPtr(/*#ref*/ps.peek.loc, ps.magicFlagD, ps.settings);
	func = new ir.FunctionType();
	func.loc = ps.peek.loc;
	func.docComment = ps.comment();

	func.ret = base;
	auto succeeded = match(ps, func, TokenType.Function);
	if (!succeeded) {
		return succeeded;
	}
	succeeded = parseParameterListFPtr(ps, /*#out*/func.params, func);
	if (!succeeded) {
		return parseFailed(ps, func);
	}
	func.isArgRef = new bool[](func.params.length);
	func.isArgOut = new bool[](func.params.length);

	return Succeeded;
}

ParseStatus parseDelegateType(ParserStream ps, out ir.DelegateType func, ir.Type base)
{
	warningOldStyleDelegateType(/*#ref*/ps.peek.loc, ps.magicFlagD, ps.settings);
	func = new ir.DelegateType();
	func.loc = ps.peek.loc;

	func.ret = base;
	auto succeeded = match(ps, func, TokenType.Delegate);
	if (!succeeded) {
		return succeeded;
	}
	succeeded = parseParameterListFPtr(ps, /*#out*/func.params, func);
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
	auto matchedComma = false;
	while (ps.peek.type != TokenType.CloseParen && !ps.eof) {
		matchedComma = false;
		if (matchIf(ps, TokenType.TripleDot)) {
			parentCallable.hasVarArgs = true;
			break;
		}
		ir.Variable var;
		succeeded = parseParameter(ps, /*#out*/var);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Variable);
		}
		types ~= var.type;
		matchedComma = matchIf(ps, TokenType.Comma);
	}
	if (matchedComma) {
		return parseExpected(ps, /*#ref*/ps.peek.loc, ir.NodeType.Function,
			"parameter list's closing ')' character, not ','");
	}
	return match(ps, ir.NodeType.Variable, TokenType.CloseParen);
}

ParseStatus parseParameterList(ParserStream ps, out ir.Variable[] vars, ir.CallableType parentCallable)
{
	auto succeeded = match(ps, ir.NodeType.Function, TokenType.OpenParen);
	if (!succeeded) {
		return succeeded;
	}
	auto matchedComma = false;
	while (ps.peek.type != TokenType.CloseParen && !ps.eof) {
		matchedComma = false;
		if (matchIf(ps, TokenType.TripleDot)) {
			if (parentCallable is null) {
				return unexpectedToken(ps, ir.NodeType.Function);
			}
			parentCallable.hasVarArgs = true;
			break;
		}
		ir.Variable var;
		succeeded = parseParameter(ps, /*#out*/var);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Function);
		}
		// foo(int a, int[] b...)
		if (matchIf(ps, TokenType.TripleDot)) {
			if (ps.peek.type != TokenType.CloseParen) {
				return parseExpected(ps, /*#ref*/ps.peek.loc, ir.NodeType.Function, 
				                     "homogenous variadic argument to be final argument");
			}
			parentCallable.hasVarArgs = false;
			parentCallable.homogenousVariadic = true;
		}
		vars ~= var;
		// foo(int a, int b, ...)
		matchedComma = matchIf(ps, TokenType.Comma);
		if (matchedComma) {
			if (matchIf(ps, TokenType.TripleDot)) {
				if (ps.peek.type != TokenType.CloseParen) {
					return parseExpected(ps, /*#ref*/ps.peek.loc, ir.NodeType.Function,
					                     "varargs to be final argument");
				}
				parentCallable.hasVarArgs = true;
				matchedComma = false;
			}
		}
	}
	if (matchedComma) {
		return parseExpected(ps, /*#ref*/ps.peek.loc, ir.NodeType.Function,
			"parameter list's closing ')' character, not ','");
	}
	return match(ps, ir.NodeType.Function, TokenType.CloseParen);
}

ParseStatus parseParameter(ParserStream ps, out ir.Variable p)
{
	p = new ir.Variable();
	p.storage = ir.Variable.Storage.Function;
	Location origin = ps.peek.loc;

	bool isOut, isIn, isRef;
	while (ps == TokenType.Ref || ps == TokenType.Out || ps == TokenType.In) {
		auto tisRef = matchIf(ps, TokenType.Ref);
		if (!isRef) {
			isRef = tisRef;
		}
		auto tisOut = matchIf(ps, TokenType.Out);
		if (!isOut) {
			isOut = tisOut;
		}
		auto tisIn = matchIf(ps, TokenType.In);
		if (!isIn) {
			isIn = tisIn;
		}
	}

	auto colon = isColonDeclaration(ps);
	ParseStatus succeeded;
	if (!colon) {
		succeeded = parseType(ps, /*#out*/p.type);
		if (!succeeded) {
			return parseFailed(ps, p);
		}
	}
	if (isIn) {
		auto constStorage = buildStorageType(/*#ref*/ps.peek.loc, ir.StorageType.Kind.Const, p.type);
		auto scopeStorage = buildStorageType(/*#ref*/ps.peek.loc, ir.StorageType.Kind.Scope, constStorage);
		p.type = scopeStorage;
	}
	if (colon) {
		p.name = ps.peek.value;
		succeeded = match(ps, p, TokenType.Identifier);
		if (!succeeded) {
			return succeeded;
		}
		succeeded = match(ps, p, TokenType.Colon);
		if (!succeeded) {
			return succeeded;
		}
		succeeded = parseType(ps, /*#out*/p.type);
		if (!succeeded) {
			return parseFailed(ps, p);
		}
	} else if (ps.peek.type == TokenType.Identifier) {
		Token name = ps.get();
		p.name = name.value;
	} else if (ps.peek.type != TokenType.Comma && ps.peek.type != TokenType.CloseParen) {
		return parseExpected(ps, /*#ref*/ps.peek.loc, p, "',', ')', or an identifier");
	}
	if (matchIf(ps, TokenType.Assign)) {
		succeeded = parseExp(ps, /*#out*/p.assign);
		if (!succeeded) {
			return parseFailed(ps, p);
		}
	}
	p.loc = ps.peek.loc - origin;
	if (isRef || isOut) {
		auto s = new ir.StorageType();
		s.loc = origin;
		s.type = isRef ? ir.StorageType.Kind.Ref : ir.StorageType.Kind.Out;
		s.base = p.type;
		p.type = s;
	}

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
		p.loc = end.loc - origin;
		p.base = outType;
		outType = p;
		break;
	case TokenType.OpenBracket:
		ps.get();
		if (ps.peek.type == TokenType.CloseBracket) {
			// Dynamic array.
			auto end = ps.get();
			auto a = new ir.ArrayType();
			a.loc = end.loc - origin;
			a.base = outType;
			outType = a;
		} else if (isPrimitiveTypeToken(ps.peek.type) ||
			isStorageTypeToken(ps.peek.type)) {
			// Unambiguous associative array.
			/* The expression parser can handle an identifier being maybe a type,
			 * but not u32 (say) on its own, so handle that case here.
			 */
			auto a = new ir.AAType();
			a.value = outType;
			auto succeeded = parseType(ps, /*#out*/a.key);
			if (!succeeded) {
				return parseFailed(ps, outType);
			}
			succeeded = match(ps, outType, TokenType.CloseBracket);
			if (!succeeded) {
				return succeeded;
			}
			outType = a;
		} else if (ps == [TokenType.IntegerLiteral, TokenType.CloseBracket]) {
			// Static array.
			auto sa = new ir.StaticArrayType();
			sa.loc = ps.peek.loc - origin;
			sa.base = outType;
			auto tmp = removeUnderscores(ps.peek.value);
			sa.length = cast(size_t)toInt(tmp);
			ps.get();
			ps.get();
			outType = sa;
		} else {
			// Static or associative array.
			auto a = new ir.AmbiguousArrayType();
			auto succeeded = parseExp(ps, /*#out*/a.child);
			if (!succeeded) {
				return parseFailed(ps, outType);
			}
			a.loc = ps.peek.loc - origin;
			succeeded = match(ps, outType, TokenType.CloseBracket);
			if (!succeeded) {
				return succeeded;
			}
			a.base = outType;
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
	ptype.loc = ps.peek.loc;
	ptype.originalToken = ps.peek;
	switch (ps.peek.type) {
	case TokenType.Byte, TokenType.I8:
		ptype.type = ir.PrimitiveType.Kind.Byte;
		break;
	case TokenType.Short, TokenType.I16:
		ptype.type = ir.PrimitiveType.Kind.Short;
		break;
	case TokenType.Int, TokenType.I32:
		ptype.type = ir.PrimitiveType.Kind.Int;
		break;
	case TokenType.Long, TokenType.I64:
		ptype.type = ir.PrimitiveType.Kind.Long;
		break;
	case TokenType.Ubyte, TokenType.U8:
		ptype.type = ir.PrimitiveType.Kind.Ubyte;
		break;
	case TokenType.Ushort, TokenType.U16:
		ptype.type = ir.PrimitiveType.Kind.Ushort;
		break;
	case TokenType.Uint, TokenType.U32:
		ptype.type = ir.PrimitiveType.Kind.Uint;
		break;
	case TokenType.Ulong, TokenType.U64:
		ptype.type = ir.PrimitiveType.Kind.Ulong;
		break;
	case TokenType.Float, TokenType.F32:
		ptype.type = ir.PrimitiveType.Kind.Float;
		break;
	case TokenType.Double, TokenType.F64:
		ptype.type = ir.PrimitiveType.Kind.Double;
		break;
	default: ptype.type = cast(ir.PrimitiveType.Kind)ps.peek.type;
	}

	ps.get();
	return ptype;
}

// If templateName is non empty, this is being parsed from a template definition.
ParseStatus parseNewFunction(ParserStream ps, out ir.Function func, string templateName = "")
{
	func = new ir.Function();
	func.type = new ir.FunctionType();
	func.docComment = ps.comment();
	func.loc = ps.peek.loc;
	func.type.loc = ps.peek.loc;

	Token nameTok;
	if (templateName.length == 0) {
		auto succeeded = match(ps, func, TokenType.Fn);
		if (!succeeded) {
			return succeeded;
		}

		succeeded = match(ps, func, TokenType.Identifier, /*#out*/nameTok);
		if (!succeeded) {
			return succeeded;
		}
		func.name = nameTok.value;
	} else {
		func.name = templateName;
		nameTok.value = func.name;
	}

	auto succeeded = match(ps, func, TokenType.OpenParen);
	if (!succeeded) {
		return succeeded;
	}

	size_t i;
	auto hadComma = false;
	while (ps != TokenType.CloseParen) {
		hadComma = false;
		if (matchIf(ps, TokenType.TripleDot)) {
			func.type.hasVarArgs = true;
			break;
		}
		bool argRef, argOut, argIn;
		while (ps == TokenType.Out || ps == TokenType.In || ps == TokenType.Ref) {
			auto targRef = matchIf(ps, TokenType.Ref);
			if (targRef && argRef) {
				return parseFailed(ps, func);
			}
			argRef = targRef;
			auto targOut = matchIf(ps, TokenType.Out);
			if (targOut && argOut) {
				return parseFailed(ps, func);
			}
			argOut = targOut;
			auto targIn = matchIf(ps, TokenType.In);
			if (targIn && argIn) {
				return parseFailed(ps, func);
			}
			argIn = targIn;
		}
		if (argRef && argOut) {
			return parseFailed(ps, func);
		}
		auto p = new ir.FunctionParam();
		p.index = i++;
		p.func = func;
		p.loc = ps.peek.loc;
		ir.Type t;
		bool eof;
		if (ps.lookahead(1, /*#out*/eof).type == TokenType.Colon) {
			succeeded = match(ps, p, TokenType.Identifier, /*#out*/nameTok);
			if (!succeeded) {
				return succeeded;
			}
			p.name = nameTok.value;
			succeeded = match(ps, p, TokenType.Colon);
		} else if (ps.lookahead(0, /*#out*/eof).type == TokenType.Identifier &&
		           ps.lookahead(1, /*#out*/eof).type != TokenType.Comma &&
			   ps.lookahead(1, /*#out*/eof).type != TokenType.CloseParen &&
			   ps.lookahead(1, /*#out*/eof).type != TokenType.Asterix &&
			   ps.lookahead(1, /*#out*/eof).type != TokenType.OpenBracket &&
			   ps.lookahead(1, /*#out*/eof).type != TokenType.Dot) {
			// Old style declaration in new-style function.
			ps.get();
			return parseExpected(ps, /*#ref*/ps.peek.loc, p, "new-style declaration (using a colon)");
		}
		succeeded = parseType(ps, /*#out*/t);
		if (!succeeded) {
			return succeeded;
		}
		if (argIn) {
			auto constStorage = buildStorageType(/*#ref*/p.loc, ir.StorageType.Kind.Const, t);
			auto scopeStorage = buildStorageType(/*#ref*/p.loc, ir.StorageType.Kind.Scope, constStorage);
			t = constStorage;
		}
		func.type.params ~= t;
		func.type.isArgRef ~= argRef;
		func.type.isArgOut ~= argOut;
		if (matchIf(ps, TokenType.Assign)) {
			succeeded = parseExp(ps, /*#out*/p.assign);
			if (!succeeded) {
				return succeeded;
			}
		}
		func.params ~= p;
		hadComma = matchIf(ps, TokenType.Comma);
		if (matchIf(ps, TokenType.TripleDot)) {
			func.type.hasVarArgs = hadComma;
			func.type.homogenousVariadic = !hadComma;
			if (ps != TokenType.CloseParen) {
				return parseFailed(ps, func);
			}
			hadComma = false;
		}
	}
	
	if (hadComma) {
		return parseExpected(ps, /*#ref*/ps.peek.loc, func,
			"parameter list's closing ')' character, not ','");
	}

	succeeded = match(ps, func, TokenType.CloseParen);
	if (!succeeded) {
		return succeeded;
	}

	bool paren = matchIf(ps, TokenType.OpenParen);

	if (ps == TokenType.OpenBrace || ps == TokenType.Semicolon) {
		func.type.ret = buildVoid(/*#ref*/func.loc);
	} else {
		succeeded = parseType(ps, /*#out*/func.type.ret);
		if (!succeeded) {
			return succeeded;
		}
		if (matchIf(ps, TokenType.Comma)) {
			// TODO: Parse multiple return values here.
			return unsupportedFeature(ps, func, "multiple return types");
		}
	}

	if (paren) {
		succeeded = match(ps, func, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
	}

	bool inBlocks = ps.peek.type != TokenType.Semicolon;
	while (inBlocks) {
		bool _in, _out;
		switch (ps.peek.type) {
		case TokenType.In:
			ps.get();
			// <in> { }
			if (_in) {
				return parseExpected(ps, /*#ref*/ps.peek.loc, func, "only one in block");
			}
			_in = true;
			succeeded = parseBraceCountedTokenList(ps, /*#out*/func.tokensIn, func);
			if (!succeeded) {
				return parseFailed(ps, func);
			}
			break;
		case TokenType.Out:
			ps.get();
			// <out>
			if (_out) {
				return parseExpected(ps, /*#ref*/ps.peek.loc, func, "only one out block");
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
			succeeded = parseBraceCountedTokenList(ps, /*#out*/func.tokensOut, func);
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
			succeeded = parseBraceCountedTokenList(ps, /*#out*/func.tokensBody, func);
			if (!succeeded) {
				return parseFailed(ps, func);
			}
			break;
		default:
			return parseExpected(ps, /*#ref*/ps.peek.loc, func, "block declaration");
		}
	}
	matchIf(ps, TokenType.Semicolon);

	return Succeeded;
}

ParseStatus parseBraceCountedTokenList(ParserStream ps, out ir.Token[] tokens, ir.Node owner)
{
	if (ps.peek.type != TokenType.OpenBrace) {
		return parseFailed(ps, ir.NodeType.Function);
	}
	size_t index = ps.saveTokens();
	int braceDepth;
	do {
		auto t = ps.get();
		if (t.type == TokenType.OpenBrace) {
			braceDepth++;
		} else if (t.type == TokenType.CloseBrace) {
			braceDepth--;
		} else if (ps.eof) {
			return parseExpected(ps, /*#ref*/ps.peek.loc, owner, "closing brace");
		}
	} while (braceDepth > 0);
	tokens = ps.doneSavingTokens(index);
	return Succeeded;
}

ParseStatus parseFunction(ParserStream ps, out ir.Function func, ir.Type base)
{
	func = new ir.Function();
	func.type = new ir.FunctionType();
	func.docComment = base.docComment;
	ps.pushCommentLevel();
	scope (success) {
		ps.popCommentLevel();
	}

	// <int> add(int a, int b) { }
	func.type.ret = base;

	// int <add>(int a, int b) {}
	Token nameTok;
	auto succeeded = match(ps, func, TokenType.Identifier, /*#out*/nameTok);
	if (!succeeded) {
		return succeeded;
	}
	func.name = nameTok.value;
	func.loc = nameTok.loc;

	// int add<(int a, int b)> {}
	ir.Variable[] params;
	succeeded = parseParameterList(ps, /*#out*/params, func.type);
	if (!succeeded) {
		return parseFailed(ps, func);
	}
	foreach (i, param; params) {
		func.type.params ~= param.type;
		func.type.isArgRef ~= false;
		func.type.isArgOut ~= false;
		auto p = new ir.FunctionParam();
		p.loc = param.loc;
		p.name = param.name;
		p.index = i;
		p.assign = param.assign;
		p.func = func;
		func.params ~= p;
	}
	//func.type.params = parseParameterList(ps, func.type);
	func.type.loc = ps.previous.loc - func.type.ret.loc;

	bool inBlocks = ps.peek.type != TokenType.Semicolon;
	while (inBlocks) {
		bool _in, _out;
		switch (ps.peek.type) {
		case TokenType.In:
			ps.get();
			// <in> { }
			if (_in) {
				return parseExpected(ps, /*#ref*/ps.peek.loc, func, "only one in block");
			}
			_in = true;
			succeeded = parseBraceCountedTokenList(ps, /*#out*/func.tokensIn, func);
			if (!succeeded) {
				return parseFailed(ps, func);
			}
			break;
		case TokenType.Out:
			ps.get();
			// <out>
			if (_out) {
				return parseExpected(ps, /*#ref*/ps.peek.loc, func, "only one out block");
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
			succeeded = parseBraceCountedTokenList(ps, /*#out*/func.tokensOut, func);
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
			succeeded = parseBraceCountedTokenList(ps, /*#out*/func.tokensBody, func);
			if (!succeeded) {
				return parseFailed(ps, func);
			}
			break;
		default:
			return parseExpected(ps, /*#ref*/ps.peek.loc, func, "block declaration");
		}
	}
	matchIf(ps, TokenType.Semicolon);

	return Succeeded;
}

/*!
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
	bs.loc = ps.peek.loc;

	auto succeeded = match(ps, bs, TokenType.OpenBrace);
	if (!succeeded) {
		return succeeded;
	}

	succeeded = eatComments(ps);
	if (!succeeded) {
		return succeeded;
	}
	auto sink = new NodeSink();
	while (ps != TokenType.CloseBrace && !ps.eof) {
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

ParseStatus parseEnumDeclaration(ParserStream ps, out ir.EnumDeclaration edecl, bool standalone)
{
	edecl = new ir.EnumDeclaration();
	edecl.loc = ps.peek.loc;
	auto comment = ps.comment();

	Token nameTok;
	auto succeeded = match(ps, edecl, TokenType.Identifier, /*#out*/nameTok);
	if (!succeeded) {
		return succeeded;
	}
	edecl.name = nameTok.value;

	if (matchIf(ps, TokenType.Colon)) {
		succeeded = parseType(ps, /*#out*/edecl.type);
		if (!succeeded) {
			parseFailed(ps, edecl);
		}
	}

	if (matchIf(ps, TokenType.Assign)) {
		succeeded = parseExp(ps, /*#out*/edecl.assign);
		if (!succeeded) {
			return parseFailed(ps, edecl);
		}
	}

	edecl.docComment = comment;
	if (edecl.docComment.length == 0) {
		ps.retroComment = edecl;
	}

	edecl.isStandalone = standalone;
	if (standalone) {
		edecl.access = ir.Access.Public;
	}
	return eatComments(ps);
}
