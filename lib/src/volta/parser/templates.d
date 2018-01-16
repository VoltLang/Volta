/*#D*/
// Copyright © 2017, Bernard Helyer.  All rights reserved.
// Copyright © 2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.parser.templates;

import ir = volta.ir;
import volta.util.util;

import volta.parser.base;
import volta.parser.declaration;
import volta.parser.toplevel;
import volta.parser.expression;
import volta.ir.token : isPrimitiveTypeToken;

/*!
 * Returns: true if ps is at a template instantiation, false otherwise.
 */
bool isTemplateInstance(ParserStream ps)
{
	if (ps.magicFlagD) {
		return (ps == [TokenType.Alias, TokenType.Identifier, TokenType.Assign, TokenType.Identifier, TokenType.Bang]) != 0;
	}
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
	ps.get();
	ps.get();
	if (ps == TokenType.Mixin) {
		return true;
	}
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
	if (isPrimitiveTypeToken(ps.peek.type)) {
		return true;
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

ParseStatus parseLegacyTemplateInstance(ParserStream ps, out ir.Struct s)
{
	s = new ir.Struct();
	s.loc = ps.peek.loc;
	string nam;
	auto succeeded = parseTemplateInstance(ps, /*#out*/s.templateInstance, /*#out*/nam);
	s.templateInstance.explicitMixin = true;
	s.name = nam;
	return succeeded;
}

ParseStatus parseTemplateInstance(ParserStream ps, out ir.TemplateInstance ti, out string instanceName)
{
	ti = new ir.TemplateInstance();
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
	instanceName = nameTok.value;

	succeeded = match(ps, ti, TokenType.Assign);
	if (!succeeded) {
		return succeeded;
	}

	ti.explicitMixin = matchIf(ps, TokenType.Mixin);

	succeeded = parseQualifiedName(ps, /*#out*/ti.name);
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
