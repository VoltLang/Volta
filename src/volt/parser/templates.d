// Copyright © 2017, Bernard Helyer.  All rights reserved.
// Copyright © 2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.templates;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.parser.base;
import volt.parser.declaration;
import volt.parser.toplevel;

/**
 * Returns: true if ps is at a template instantiation, false otherwise.
 */
bool isTemplateInstance(ParserStream ps)
{
	if (ps.settings.internalD) {
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
	ps.get();
	bool result = (ps == [TokenType.Identifier, TokenType.Assign, TokenType.Identifier, TokenType.Bang] ||
		ps == [TokenType.Identifier, TokenType.Assign, TokenType.Mixin, TokenType.Identifier, TokenType.Bang]) != 0;
	ps.restore(mark);
	return result;
}


/**
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
	if (!ps.settings.internalD) {
		result = (ps == [TokenType.Identifier, TokenType.Bang]) != 0;
	} else {
		result = (ps == [TokenType.Identifier, TokenType.OpenParen]) && !functionTemplate;
	}
	ps.restore(mark);
	return result;
}

ParseStatus parseLegacyTemplateInstance(ParserStream ps, out ir.Struct s)
{
	s = new ir.Struct();
	s.loc = ps.peek.loc;
	string nam;
	auto succeeded = parseTemplateInstance(ps, s.templateInstance, nam);
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
		assert(ps.settings.internalD);
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
	auto succeeded = match(ps, ti, TokenType.Identifier, nameTok);
	if (!succeeded) {
		return succeeded;
	}
	instanceName = nameTok.value;

	succeeded = match(ps, ti, TokenType.Assign);
	if (!succeeded) {
		return succeeded;
	}

	ti.explicitMixin = matchIf(ps, TokenType.Mixin);

	succeeded = match(ps, ti, TokenType.Identifier, nameTok);
	if (!succeeded) {
		return succeeded;
	}
	ti.name = nameTok.value;

	succeeded = match(ps, ti, TokenType.Bang);
	if (!succeeded) {
		return succeeded;
	}

	if (ps == TokenType.OpenParen) {
		ps.get();
		while (ps != TokenType.CloseParen) {
			ir.Type t;
			succeeded = parseType(ps, t);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TemplateInstance);
			}
			ti.typeArguments ~= t;
			if (ps == TokenType.Comma) {
				ps.get();
			}
		}
		succeeded = match(ps, ti, TokenType.CloseParen);
		if (!succeeded) {
			return succeeded;
		}
	} else {
		ir.Type t;
		succeeded = parseType(ps, t);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TemplateInstance);
		}
		ti.typeArguments ~= t;
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
	if (!ps.settings.internalD) {
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
			td.typeParameters ~= nameTok.value;
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
		td.typeParameters ~= nameTok.value;
	}

	final switch (td.kind) {
	case ir.TemplateKind.Struct:
		succeeded = parseStruct(ps, td._struct, td.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TemplateDefinition);
		}
		break;
	case ir.TemplateKind.Union:
		succeeded = parseUnion(ps, td._union, td.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TemplateDefinition);
		}
		break;
	case ir.TemplateKind.Class:
		succeeded = parseClass(ps, td._class, td.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TemplateDefinition);
		}
		break;
	case ir.TemplateKind.Interface:
		succeeded = parseInterface(ps, td._interface, td.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TemplateDefinition);
		}
		break;
	case ir.TemplateKind.Function:
		succeeded = parseNewFunction(ps, td._function, td.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TemplateDefinition);
		}
		break;
	}

	td.loc = ps.peek.loc - origin;
	return Succeeded;
}
