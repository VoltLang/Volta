/*#D*/
// Copyright 2017, Bernard Helyer.
// Copyright 2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volta.parser.templates;

import ir = volta.ir;
import volta.util.util;

import volta.parser.base;
import volta.parser.declaration;
import volta.parser.toplevel;
import volta.parser.expression;
import volta.ir.token : isPrimitiveTypeToken;


bool isLegacyTemplateInstance(ParserStream ps)
{
	return (ps == [TokenType.Alias, TokenType.Identifier, TokenType.Assign, TokenType.Identifier, TokenType.Bang]) != 0;
}

/*!
 * Returns: true if ps is at a template instantiation, false otherwise.
 */
bool isTemplateInstance(ParserStream ps)
{
	switch (ps.peek.type) {
	case TokenType.Struct:
	case TokenType.Class:
	case TokenType.Union:
	case TokenType.Interface:
	case TokenType.Fn:
		break;
	default:
		return false;
	}

	auto mark = ps.save();
	scope (exit) ps.restore(mark);
	ps.get();
	if (ps != [TokenType.Identifier, TokenType.Assign]) {
		return false;
	}
	ps.get(); // TokenType.Identifier
	ps.get(); // TokenType.Assign

	if (ps == TokenType.Mixin) {
		return true;
	}

	// Gobble up Qualified name
	while (ps == TokenType.Identifier || ps == TokenType.Dot) {
		ps.get();
	}

	if (ps == TokenType.Bang) {
		return true;
	}

	return false;
}


/*!
 * Returns: true if ps is at a template definition, false otherwise.
 */
bool isTemplateDefinition(ParserStream ps)
{
	bool functionTemplate = false;
	switch (ps.peek.type) {
	case TokenType.Struct:
	case TokenType.Class:
	case TokenType.Union:
	case TokenType.Interface:
		break;
	case TokenType.Fn:
		functionTemplate = true;
		break;
	default:
		return false;
	}

	auto mark = ps.save();
	ps.get();
	bool result;
	if (!ps.magicFlagD) {
		result = (ps == [TokenType.Identifier, TokenType.Bang]) != 0;
	} else {
		result = (ps == [TokenType.Identifier, TokenType.OpenParen]) && !functionTemplate;
	}
	ps.restore(mark);
	return result;
}

/*!
 * Returns: true if the stream is at a point where we know it's a type, false otherwise.
 */
bool isUnambigouslyType(ParserStream ps)
{
	switch (ps.peek.type) {
	case ir.TokenType.Bool, ir.TokenType.Ubyte, ir.TokenType.Byte,
		 ir.TokenType.Short, ir.TokenType.Ushort,
		 ir.TokenType.Int, ir.TokenType.Uint, ir.TokenType.Long,
		 ir.TokenType.Ulong, ir.TokenType.Void, ir.TokenType.Float,
		 ir.TokenType.Double, ir.TokenType.Real, ir.TokenType.Char,
		 ir.TokenType.Wchar, ir.TokenType.Dchar, ir.TokenType.I8,
		 ir.TokenType.I16, ir.TokenType.I32, ir.TokenType.I64,
		 ir.TokenType.U8, ir.TokenType.U16, ir.TokenType.U32, ir.TokenType.U64,
		 ir.TokenType.F32, ir.TokenType.F64,
		 ir.TokenType.Const, ir.TokenType.Immutable, ir.TokenType.Scope:
		return true;
	default:
		break;
	}
	auto mark = ps.save();
	ps.get();
	bool retval;
	while (ps != TokenType.Semicolon && !ps.eof && ps != TokenType.CloseParen && ps != TokenType.Comma) {
		if (ps == TokenType.Identifier || ps == TokenType.Dot) {
			ps.get();
			continue;
		}
		if (ps == TokenType.OpenBracket) {
			ps.get();
			// T[] <- this won't be valid at compile time, so treat it like a type.
			retval = ps == TokenType.CloseBracket;
			break;
		} else {
			break;
		}
		assert(false);
	}
	ps.restore(mark);
	return retval;
}

ParseStatus parseLegacyTemplateInstance(ParserStream ps, out ir.TemplateInstance ti)
{
	auto succeeded = parseTemplateInstance(ps, /*#out*/ti);
	ti.explicitMixin = true;
	return succeeded;
}

ParseStatus parseTemplateInstance(ParserStream ps, out ir.TemplateInstance ti)
{
	ti = new ir.TemplateInstance();
	ti.docComment = ps.comment();
	auto origin = ps.peek.loc;

	switch (ps.peek.type) {
	case TokenType.Alias:
		assert(ps.magicFlagD);
		ti.kind = ir.TemplateKind.Struct;
		break;
	case TokenType.Struct:
		ti.kind = ir.TemplateKind.Struct;
		break;
	case TokenType.Class:
		ti.kind = ir.TemplateKind.Class;
		break;
	case TokenType.Union:
		ti.kind = ir.TemplateKind.Union;
		break;
	case TokenType.Interface:
		ti.kind = ir.TemplateKind.Interface;
		break;
	case TokenType.Fn:
		ti.kind = ir.TemplateKind.Function;
		break;
	default:
		return unexpectedToken(ps, ir.NodeType.TemplateInstance);
	}
	ps.get();

	Token nameTok;
	auto succeeded = match(ps, ti, TokenType.Identifier, /*#out*/nameTok);
	if (!succeeded) {
		return succeeded;
	}
	ti.instanceName = nameTok.value;

	succeeded = match(ps, ti, TokenType.Assign);
	if (!succeeded) {
		return succeeded;
	}

	ti.explicitMixin = matchIf(ps, TokenType.Mixin);

	succeeded = parseQualifiedName(ps, /*#out*/ti.definitionName);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.TemplateInstance);
	}

	succeeded = match(ps, ti, TokenType.Bang);
	if (!succeeded) {
		return succeeded;
	}

	ParseStatus parseArgument()
	{
		if (isUnambigouslyType(ps)) {
			ir.Type t;
			succeeded = parseType(ps, /*#out*/t);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TemplateInstance);
			}
			ti.arguments ~= t;
		} else {
			ir.Exp e;
			succeeded = parseExp(ps, /*#out*/e);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TemplateInstance);
			}
			ti.arguments ~= e;
		}
		return Succeeded;
	}

	if (ps == TokenType.OpenParen) {
		ps.get();
		while (ps != TokenType.CloseParen) {
			if (!parseArgument()) {
				return Failed;
			}
			if (ps == TokenType.Comma) {
				ps.get();
			}
		}
		succeeded = match(ps, ti, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
	} else {
		if (!parseArgument()) {
			return Failed;
		}
	}

	succeeded = match(ps, ti, TokenType.Semicolon);
	if (!succeeded) {
		return succeeded;
	}

	ti.loc = ps.peek.loc - origin;
	return Succeeded;
}

ParseStatus parseTemplateDefinition(ParserStream ps, out ir.TemplateDefinition td)
{
	td = new ir.TemplateDefinition();
	td.docComment = ps.comment();
	auto origin = ps.peek.loc;

	switch (ps.peek.type) {
	case TokenType.Struct:
		td.kind = ir.TemplateKind.Struct;
		break;
	case TokenType.Class:
		td.kind = ir.TemplateKind.Class;
		break;
	case TokenType.Union:
		td.kind = ir.TemplateKind.Union;
		break;
	case TokenType.Interface:
		td.kind = ir.TemplateKind.Interface;
		break;
	case TokenType.Fn:
		td.kind = ir.TemplateKind.Function;
		break;
	default:
		return unexpectedToken(ps, ir.NodeType.TemplateDefinition);
	}
	ps.get();

	auto nameTok = ps.get();
	if (nameTok.type != TokenType.Identifier) {
		return unexpectedToken(ps, ir.NodeType.Identifier);
	}
	td.name = nameTok.value;

	ParseStatus succeeded;
	if (!ps.magicFlagD) {
		succeeded = match(ps, td, TokenType.Bang);
		if (!succeeded) {
			return succeeded;
		}
	}

	if (ps.peek.type == TokenType.OpenParen) {
		// Foo!(...)
		succeeded = match(ps, td, TokenType.OpenParen);
		if (!succeeded) {
			return succeeded;
		}
		while (ps != TokenType.CloseParen) {
			nameTok = ps.get();
			if (nameTok.type != TokenType.Identifier) {
				return unexpectedToken(ps, ir.NodeType.Identifier);
			}
			ir.TemplateDefinition.Parameter param;
			param.name = nameTok.value;
			if (matchIf(ps, TokenType.Colon)) {
				succeeded = parseType(ps, /*#out*/param.type);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.TemplateDefinition);
				}
			}
			td.parameters ~= param;
			if (ps == TokenType.Comma) {
				ps.get();
			}
		}
		ps.get();  // Eat the close paren.
	} else {
		// Foo!T
		nameTok = ps.get();
		if (nameTok.type != TokenType.Identifier) {
			return unexpectedToken(ps, ir.NodeType.Identifier);
		}
		ir.TemplateDefinition.Parameter param;
		param.name = nameTok.value;
		td.parameters ~= param;
	}

	final switch (td.kind) {
	case ir.TemplateKind.Struct:
		succeeded = parseStruct(ps, /*#out*/td._struct, td.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TemplateDefinition);
		}
		break;
	case ir.TemplateKind.Union:
		succeeded = parseUnion(ps, /*#out*/td._union, td.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TemplateDefinition);
		}
		break;
	case ir.TemplateKind.Class:
		succeeded = parseClass(ps, /*#out*/td._class, td.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TemplateDefinition);
		}
		break;
	case ir.TemplateKind.Interface:
		succeeded = parseInterface(ps, /*#out*/td._interface, td.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TemplateDefinition);
		}
		break;
	case ir.TemplateKind.Function:
		succeeded = parseNewFunction(ps, /*#out*/td._function, td.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TemplateDefinition);
		}
		break;
	}

	td.loc = ps.peek.loc - origin;
	return Succeeded;
}
