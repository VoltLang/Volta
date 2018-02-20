/*#D*/
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.parser.toplevel;

import watt.conv : toInt, toLower;
import watt.text.vdoc : cleanComment;

import ir = volta.ir;
import volta.util.util;
import volta.util.copy;

import volta.errors;
import volta.ir.tokenstream;
import volta.ir.location;
import volta.ir.token : TokenType;

import volta.parser.base;
import volta.parser.declaration;
public import volta.parser.statements : parseMixinStatement;
import volta.parser.expression;
import volta.parser.statements;
import volta.parser.templates;


ParseStatus parseModule(ParserStream ps, out ir.Module mod)
{
	auto initLocation = ps.peek.loc;
	ps.pushCommentLevel();
	auto succeeded = eatComments(ps);
	if (!succeeded) {
		return succeeded;
	}
	if (ps.peek.type == TokenType.Module) {
		auto t = ps.get();

		ir.QualifiedName qn;
		succeeded = parseQualifiedName(ps, /*#out*/qn);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Module);
		}

		if (ps.peek.type != TokenType.Semicolon) {
			return unexpectedToken(ps, ir.NodeType.Module);
		}
		ps.get();

		mod = new ir.Module();
		mod.loc = initLocation;
		mod.name = qn;
		mod.docComment = ps.comment();
	} else {
		mod = new ir.Module();
		mod.loc = initLocation;
		mod.name = buildQualifiedName(/*#ref*/mod.loc, mod.loc.filename);
		mod.docComment = ps.comment();
		mod.isAnonymous = true;
	}
	mod.magicFlagD = ps.magicFlagD;
	ps.popCommentLevel();

	succeeded = parseTopLevelBlock(ps, /*#out*/mod.children, TokenType.End);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Module);
	}

	if (ps.multiDepth > 0) {
		return parseExpected(ps, /*#ref*/ps.peek.loc, ir.NodeType.Module, "@}");
	}

	// Get the global doc comments for defgroup and other commands.
	mod.globalDocComments = ps.globalDocComments;

	// Don't include the default modules in themselves.
	// Maybe move to gather or import resolver?
	if (mod.name.identifiers.length == 3 &&
	    mod.name.identifiers[0].value == "core" &&
	    mod.name.identifiers[0].value == "compiler" &&
	    mod.name.identifiers[0].value == "defaultsymbols") {
		return Succeeded;
	}

	mod.children.nodes = [
			createImport(/*#ref*/mod.loc, "core", "compiler", "defaultsymbols")
		] ~ mod.children.nodes;

	return Succeeded;
}

ir.Node createImport(ref in Location loc, scope string[] names...)
{
	auto _import = new ir.Import();
	_import.loc = loc;
	_import.names ~= new ir.QualifiedName();
	_import.names[0].loc = loc;
	foreach (i, name; names) {
		_import.names[0].identifiers ~= new ir.Identifier();
		_import.names[0].identifiers[i].loc = loc;
		_import.names[0].identifiers[i].value = name;
	}
	return _import;
}

ParseStatus parseOneTopLevelBlock(ParserStream ps, out ir.TopLevelBlock tlb)
out(result)
{
	if (result) {
		assert(tlb !is null);
	}
}
body
{
	auto succeeded = eatComments(ps);
	if (!succeeded) {
		return succeeded;
	}
	tlb = new ir.TopLevelBlock();
	tlb.loc = ps.peek.loc;

	auto sink = new NodeSink();

	bool parseIfTemplateInstance()
	{
		if (!isTemplateInstance(ps)) {
			return false;
		}
		ir.TemplateInstance ti;
		succeeded = parseTemplateInstance(ps, /*#out*/ti);
		if (succeeded) {
			sink.push(ti);
		}
		return true;
	}

	switch (ps.peek.type) {
	case TokenType.Import:
		ir.Import _import;
		succeeded = parseImport(ps, /*#out*/_import);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		sink.push(_import);
		break;
	case TokenType.Unittest:
		ir.Unittest u;
		succeeded = parseUnittest(ps, /*#out*/u);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		sink.push(u);
		break;
	case TokenType.This:
		ir.Function c;
		succeeded = parseConstructor(ps, /*#out*/c);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		sink.push(c);
		break;
	case TokenType.Tilde:  // XXX: Is this unambiguous?
		ir.Function d;
		succeeded = parseDestructor(ps, /*#out*/d);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		sink.push(d);
		break;
	case TokenType.Union:
		ir.Union u;
		if (isTemplateDefinition(ps)) {
			ir.TemplateDefinition td;
			succeeded = parseTemplateDefinition(ps, /*#out*/td);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(td);
			break;
		}
		if (parseIfTemplateInstance()) {
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			break;
		}
		succeeded = parseUnion(ps, /*#out*/u);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		sink.push(u);
		break;
	case TokenType.Struct:
		ir.Struct s;
		if (isTemplateDefinition(ps)) {
			ir.TemplateDefinition td;
			succeeded = parseTemplateDefinition(ps, /*#out*/td);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(td);
			break;
		}
		if (parseIfTemplateInstance()) {
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			break;
		}
		succeeded = parseStruct(ps, /*#out*/s);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		sink.push(s);
		break;
	case TokenType.Class:
		ir.Class c;
		if (isTemplateDefinition(ps)) {
			ir.TemplateDefinition td;
			succeeded = parseTemplateDefinition(ps, /*#out*/td);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(td);
			break;
		}
		if (parseIfTemplateInstance()) {
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			break;
		}
		succeeded = parseClass(ps, /*#out*/c);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		sink.push(c);
		break;
	case TokenType.Interface:
		ir._Interface i;
		if (isTemplateDefinition(ps)) {
			ir.TemplateDefinition td;
			succeeded = parseTemplateDefinition(ps, /*#out*/td);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(td);
			break;
		}
		if (parseIfTemplateInstance()) {
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			break;
		}
		succeeded = parseInterface(ps, /*#out*/i);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		sink.push(i);
		break;
	case TokenType.Enum:
		ir.Node[] nodes;
		succeeded = parseEnum(ps, /*#out*/nodes);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		sink.pushNodes(nodes);
		break;
	case TokenType.Mixin:
		bool eof;
		auto next = ps.lookahead(1, /*#out*/eof).type;
		if (next == TokenType.Function) {
			ir.MixinFunction m;
			succeeded = parseMixinFunction(ps, /*#out*/m);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(m);
		} else if (next == TokenType.Template) {
			ir.MixinTemplate m;
			succeeded = parseMixinTemplate(ps, /*#out*/m);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(m);
		} else {
			return unexpectedToken(ps, ir.NodeType.TopLevelBlock);
		}
		break;
	case TokenType.Const:
		bool eof;
		if (ps.lookahead(1, /*#out*/eof).type == TokenType.OpenParen) {
			goto default;
		} else {
			goto case;
		}
	case TokenType.At:
	case TokenType.Extern:
	case TokenType.Align:
	case TokenType.Deprecated:
	case TokenType.Private:
	case TokenType.Protected:
	case TokenType.Public:
	case TokenType.Export:
	case TokenType.Final:
	case TokenType.Synchronized:
	case TokenType.Override:
	case TokenType.Abstract:
	case TokenType.Inout:
	case TokenType.Nothrow:
	case TokenType.Pure: // WARNING Global/Local jumps here.
		ir.Attribute a;
		succeeded = parseAttribute(ps, /*#out*/a);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		sink.push(a);
		break;
	case TokenType.Global:
	case TokenType.Local:
		bool eof;
		auto next = ps.lookahead(1, /*#out*/eof).type;
		if (next == TokenType.Tilde) {
			goto case TokenType.Tilde;
		} else if (next == TokenType.This) {
			goto case TokenType.This;
		}
		goto case TokenType.Pure; // To attribute parsing.
	case TokenType.Version:
	case TokenType.Debug:
		ir.ConditionTopLevel c;
		succeeded = parseConditionTopLevel(ps, /*#out*/c);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		sink.push(c);
		break;
	case TokenType.Static:
		bool eof;
		auto next = ps.lookahead(1, /*#out*/eof).type;
		if (next == TokenType.Tilde) {
			goto case TokenType.Tilde;
		} else if (next == TokenType.This) {
			goto case TokenType.This;
		} else if (next == TokenType.Assert) {
			ir.AssertStatement s;
			succeeded = parseAssertStatement(ps, /*#out*/s);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(s);
		} else if (next == TokenType.If) {
			goto case TokenType.Version;
		} else {
			ir.Attribute a;
			succeeded = parseAttribute(ps, /*#out*/a);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(a);
		}
		break;
	case TokenType.Semicolon:
		// Just ignore EmptyTopLevel
		ps.get();
		break;
	default:
		succeeded = parseVariable(ps, sink.push);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		break;
	}

	tlb.nodes = sink.array;

	assert(tlb.nodes.length == 0 || tlb.nodes[$-1] !is null);
	return Succeeded;
}

bool ifDocCommentsUntilEndThenSkip(ParserStream ps)
{
	size_t n = 0;
	TokenType tt;
	bool eof;
	do {
		tt = ps.lookahead(n++, /*#out*/eof).type;
	} while (tt == TokenType.DocComment && !eof);
	if (tt == TokenType.End) {
		foreach (size_t i; 0 .. n) {
			ps.get();
		}
		return true;
	}
	return false;
}

ParseStatus parseTopLevelBlock(ParserStream ps, out ir.TopLevelBlock tlb, TokenType end)
out(result)
{
	if (result) {
		assert(tlb !is null);
	}
}
body
{
	tlb = new ir.TopLevelBlock();
	tlb.loc = ps.peek.loc;

	ps.pushCommentLevel();

	while (ps.peek.type != end && !ps.eof) {
		ir.TopLevelBlock tmp;
		auto succeeded = parseOneTopLevelBlock(ps, /*#out*/tmp);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.TopLevelBlock);
		}
		if (tmp.nodeType != ir.NodeType.Attribute) {
			ps.popCommentLevel();
			ps.pushCommentLevel();
		}
		tlb.nodes ~= tmp.nodes;

		if (ifDocCommentsUntilEndThenSkip(ps)) {
			continue;
		}
		eatComments(ps);
	}

	ps.popCommentLevel();

	return Succeeded;
}

ParseStatus parseImport(ParserStream ps, out ir.Import _import)
{
	_import = new ir.Import();
	_import.loc = ps.peek.loc;
	_import.access = ir.Access.Private;
	auto succeeded = match(ps, _import, TokenType.Import);
	if (!succeeded) {
		return succeeded;
	}

	if (ps == [TokenType.Identifier, TokenType.Assign]) {
		// import <a = b.c>
		succeeded = parseIdentifier(ps, /*#out*/_import.bind);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Import);
		}
		if (ps.peek.type != TokenType.Assign) {
			return unexpectedToken(ps, ir.NodeType.Import);
		}
		ps.get();
		if (matchIf(ps, TokenType.OpenBracket)) {
			do {
				ir.QualifiedName qname;
				succeeded = parseQualifiedName(ps, /*#out*/qname);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.Import);
				}
				_import.names ~= qname;
				matchIf(ps, TokenType.Comma);
			} while (ps != TokenType.CloseBracket);
			ps.get();
		} else {
			ir.QualifiedName qname;
			succeeded = parseQualifiedName(ps, /*#out*/qname);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Import);
			}
			_import.names ~= qname;
		}
	} else {
		if (ps == TokenType.OpenBracket) {
			return badMultiBind(ps, /*#ref*/_import.loc);
		}
		// No import bind.
		ir.QualifiedName qname;
		succeeded = parseQualifiedName(ps, /*#out*/qname);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Import);
		}
		_import.names ~= qname;
	}

	// Parse out any aliases.
	if (matchIf(ps, TokenType.Colon)) {
		// import a : <b, c = d>
		bool first = true;
		do {
			if (matchIf(ps, TokenType.Comma)) {
				if (first) {
					return parseExpected(ps, /*#ref*/ps.peek.loc, ir.NodeType.Import, "identifier");
				}
			}
			first = false;
			ir.Identifier name, assign;
			succeeded = parseIdentifier(ps, /*#out*/name);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Import);
			}
			if (ps.peek.type == TokenType.Assign) {
				ps.get();
				succeeded = parseIdentifier(ps, /*#out*/assign);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.Import);
				}
			}
			_import.aliases ~= [name, assign];
		} while (ps.peek.type == TokenType.Comma && !ps.eof);
	}

	return match(ps, ir.NodeType.Import, TokenType.Semicolon);
}

ParseStatus parseUnittest(ParserStream ps, out ir.Unittest u)
{
	u = new ir.Unittest();
	u.loc = ps.peek.loc;

	if (ps.peek.type != TokenType.Unittest) {
		return unexpectedToken(ps, ir.NodeType.Unittest);
	}
	ps.get();
	auto succeeded = parseBlock(ps, /*#out*/u._body);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Unittest);
	}

	u.docComment = ps.comment();
	return Succeeded;
}

ParseStatus parseConstructor(ParserStream ps, out ir.Function c)
{
	c = new ir.Function();
	c.kind = ir.Function.Kind.Constructor;
	c.name = "__ctor";
	c.docComment = ps.comment();

	// TODO (selfhost) Remove
	if (matchIf(ps, TokenType.Static)) {
		c.kind = ir.Function.Kind.GlobalConstructor;
	}

	if (matchIf(ps, TokenType.Local)) {
		c.kind = ir.Function.Kind.LocalConstructor;
	} else if (matchIf(ps, TokenType.Global)) {
		c.kind = ir.Function.Kind.GlobalConstructor;
	}

	// Get the loc of this.
	c.loc = ps.peek.loc;

	if (ps.peek.type != TokenType.This) {
		return unexpectedToken(ps, ir.NodeType.Function);
	}
	ps.get();

	auto pt = new ir.PrimitiveType();
	pt.type = ir.PrimitiveType.Kind.Void;
	pt.loc = c.loc;

	c.type = new ir.FunctionType();
	c.type.ret = pt;

	ir.Variable[] params;
	bool colonDeclaration = isColonDeclaration(ps);
	auto succeeded = parseParameterList(ps, /*#out*/params, c.type);
	if (params.length > 0 && !colonDeclaration) {
		warningOldStyleFunction(/*#ref*/c.loc, ps.magicFlagD, ps.settings);
	}
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Function, ir.NodeType.FunctionParam);
	}

	foreach (i, param; params) {
		c.type.params ~= param.type;
		c.type.isArgRef ~= false;
		c.type.isArgOut ~= false;
		auto p = new ir.FunctionParam();
		p.loc = param.loc;
		p.name = param.name;
		p.index = i;
		p.assign = param.assign;
		p.func = c;
		c.params ~= p;
	}
	bool inBlocks = true;
	while (inBlocks) {
		bool _in, _out;
		switch (ps.peek.type) {
		case TokenType.In:
			// <in> { }
			if (_in) {
				return parseExpected(ps, /*#ref*/ps.peek.loc, c, "one in block");
			}
			_in = true;
			if (ps != TokenType.In) {
				return unexpectedToken(ps, c);
			}
			ps.get();
			succeeded = parseBraceCountedTokenList(ps, /*#out*/c.tokensIn, c);
			if (!succeeded) {
				return parseFailed(ps, c);
			}
			break;
		case TokenType.Out:
			// <out>
			if (_out) {
				return parseExpected(ps, /*#ref*/ps.peek.loc, c, "one out block");
			}
			_out = true;
			if (ps != TokenType.Out) {
				return unexpectedToken(ps, c);
			}
			ps.get();
			if (ps.peek.type == TokenType.OpenParen) {
				// out <(result)>
				if (ps != [TokenType.OpenParen, TokenType.Identifier]) {
					return unexpectedToken(ps, c);
				}
				ps.get();
				auto identTok = ps.get();
				c.outParameter = identTok.value;
				if (ps != TokenType.CloseParen) {
					return unexpectedToken(ps, c);
				}
				ps.get();
			}
			succeeded = parseBraceCountedTokenList(ps, /*#out*/c.tokensOut, c);
			if (!succeeded) {
				return parseFailed(ps, c);
			}
			break;
		case TokenType.OpenBrace:
		case TokenType.Body:
			if (ps.peek.type == TokenType.Body) {
				ps.get();
			}
			inBlocks = false;
			auto succeeded2 = parseBraceCountedTokenList(ps, /*#out*/c.tokensBody, c);
			if (!succeeded2) {
				return parseFailed(ps, ir.NodeType.Function, ir.NodeType.BlockStatement);
			}
			break;
		default:
			return unexpectedToken(ps, ir.NodeType.Function);
		}
	}

	return Succeeded;
}

ParseStatus parseDestructor(ParserStream ps, out ir.Function d)
{
	d = new ir.Function();
	d.kind = ir.Function.Kind.Destructor;
	d.name = "__dtor";
	d.docComment = ps.comment();

	// TODO (selfhost) Remove
	if (matchIf(ps, TokenType.Static)) {
		d.kind = ir.Function.Kind.GlobalDestructor;
	}

	if (matchIf(ps, TokenType.Local)) {
		d.kind = ir.Function.Kind.LocalDestructor;
	} else if (matchIf(ps, TokenType.Global)) {
		d.kind = ir.Function.Kind.GlobalDestructor;
	}

	if (ps.peek.type != TokenType.Tilde) {
		return unexpectedToken(ps, ir.NodeType.Function);
	}
	ps.get();

	// Get the loc of ~this.
	d.loc = ps.peek.loc - ps.previous.loc;

	auto succeeded = match(ps, ir.NodeType.Function,
		[TokenType.This, TokenType.OpenParen, TokenType.CloseParen]);
	if (!succeeded) {
		return succeeded;
	}

	auto pt = new ir.PrimitiveType();
	pt.type = ir.PrimitiveType.Kind.Void;
	pt.loc = d.loc;

	d.type = new ir.FunctionType();
	d.type.ret = pt;
	succeeded = parseBraceCountedTokenList(ps, /*#out*/d.tokensBody, d);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Function, ir.NodeType.BlockStatement);
	}

	return Succeeded;
}

// If templateName is non empty, this is being parsed from a template definition.
ParseStatus parseClass(ParserStream ps, out ir.Class c, string templateName = "")
{
	c = new ir.Class();
	c.loc = ps.peek.loc;
	c.docComment = ps.comment();

	if (templateName.length == 0) {
		auto succeeded = match(ps, ir.NodeType.Class,
			[TokenType.Class, TokenType.Identifier]);
		if (!succeeded) {
			return succeeded;
		}

		auto nameTok = ps.previous;
		c.name = nameTok.value;
	} else {
		c.name = templateName;
	}

	if (matchIf(ps, TokenType.Colon)) {
		auto succeeded = parseQualifiedName(ps, /*#out*/c.parent);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Class, ir.NodeType.QualifiedName);
		}
		while (ps.peek.type != TokenType.OpenBrace && !ps.eof) {
			if (ps.peek.type != TokenType.Comma) {
				return unexpectedToken(ps, ir.NodeType.Class);
			}
			ps.get();
			ir.QualifiedName i;
			succeeded = parseQualifiedName(ps, /*#out*/i);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Class, ir.NodeType.QualifiedName);
			}
			c.interfaces ~= i;
		}
	}

	if (ps.peek.type != TokenType.OpenBrace) {
		return unexpectedToken(ps, ir.NodeType.Class);
	}
	ps.get();
	auto succeeded = parseTopLevelBlock(ps, /*#out*/c.members, TokenType.CloseBrace);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Class, ir.NodeType.TopLevelBlock);
	}

	return match(ps, ir.NodeType.Class, TokenType.CloseBrace);
}

// If templateName is non empty, this is being parsed from a template definition.
ParseStatus parseInterface(ParserStream ps, out ir._Interface i, string templateName = "")
{
	i = new ir._Interface();
	i.loc = ps.peek.loc;
	i.docComment = ps.comment();

	if (templateName.length == 0) {
		auto succeeded = match(ps, ir.NodeType.Interface,
			[TokenType.Interface, TokenType.Identifier]);
		if (!succeeded) {
			return succeeded;
		}

		auto nameTok = ps.previous;
		i.name = nameTok.value;
	} else {
		i.name = templateName;
	}

	if (matchIf(ps, TokenType.Colon)) {
		while (ps.peek.type != TokenType.OpenBrace && !ps.eof) {
			ir.QualifiedName q;
			auto succeeded = parseQualifiedName(ps, /*#out*/q);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Interface, ir.NodeType.QualifiedName);
			}
			i.interfaces ~= q;
			if (ps.peek.type != TokenType.OpenBrace) {
				if (ps.peek.type != TokenType.Comma) {
					return unexpectedToken(ps, ir.NodeType.Interface);
				}
				ps.get();
			}
		}
	}

	if (ps.peek.type != TokenType.OpenBrace) {
		return unexpectedToken(ps, ir.NodeType.Interface);
	}
	ps.get();
	auto succeeded = parseTopLevelBlock(ps, /*#out*/i.members, TokenType.CloseBrace);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Interface, ir.NodeType.TopLevelBlock);
	}

	return match(ps, ir.NodeType.Interface, TokenType.CloseBrace);
}

// If templateName is non empty, this is being parsed from a template definition.
ParseStatus parseUnion(ParserStream ps, out ir.Union u, string templateName="")
{
	u = new ir.Union();
	u.loc = ps.peek.loc;
	u.docComment = ps.comment();


	if (templateName.length == 0) {
		if (ps.peek.type != TokenType.Union) {
			return unexpectedToken(ps, ir.NodeType.Union);
		}
		ps.get();
		if (ps.peek.type == TokenType.Identifier) {
			auto nameTok = ps.get();
			u.name = nameTok.value;
		} else {
			return unsupportedFeature(ps, u, "anonymous union declarations");
		}
	} else {
		u.name = templateName;
	}

	if (ps.peek.type == TokenType.Semicolon) {
		if (u.name.length == 0) {
			if (ps.peek.type != TokenType.OpenBrace) {
				return unexpectedToken(ps, ir.NodeType.Union);
			}
			ps.get();
			if (ps.peek.type != TokenType.Semicolon) {
				return unexpectedToken(ps, ir.NodeType.Union);
			}
			ps.get();
		} else {
			return unsupportedFeature(ps, u, "opaque union declarations");
		}
	} else {
		if (ps.peek.type != TokenType.OpenBrace) {
			return unexpectedToken(ps, ir.NodeType.Union);
		}
		ps.get();
		auto succeeded = parseTopLevelBlock(ps, /*#out*/u.members, TokenType.CloseBrace);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Union);
		}

		return match(ps, ir.NodeType.Union, TokenType.CloseBrace);
	}

	return Succeeded;
}

// If templateName is non empty, this is being parsed from a template definition.
ParseStatus parseStruct(ParserStream ps, out ir.Struct s, string templateName="")
{
	s = new ir.Struct();
	s.loc = ps.peek.loc;
	s.docComment = ps.comment();

	if (templateName.length == 0) {
		if (ps.peek.type != TokenType.Struct) {
			return unexpectedToken(ps, ir.NodeType.Struct);
		}
		ps.get();
		if (ps.peek.type == TokenType.Identifier) {
			auto nameTok = ps.get();
			s.name = nameTok.value;
		} else {
			return unsupportedFeature(ps, s, "anonymous struct declarations");
		}
	} else {
		s.name = templateName;
	}

	if (ps.peek.type == TokenType.Semicolon) {
		return unsupportedFeature(ps, s, "opaque struct declarations");
	} else {
		if (ps.peek.type != TokenType.OpenBrace) {
			return unexpectedToken(ps, ir.NodeType.Struct);
		}
		ps.get();
		auto succeeded = parseTopLevelBlock(ps, /*#out*/s.members, TokenType.CloseBrace);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Struct);
		}

		return match(ps, ir.NodeType.Struct, TokenType.CloseBrace);
	}
}

ParseStatus parseEnum(ParserStream ps, out ir.Node[] output)
{
	auto origin = ps.peek.loc;

	if (ps != TokenType.Enum) {
		return unexpectedToken(ps, ir.NodeType.Enum);
	}
	ps.get();

	ir.Enum namedEnum;

	/* We need to treat `enum A : TYPE =` and `enum A : TYPE {` differently,
	 * but TYPE can be arbitrarly large (think `i32*******[32]`).
	 * Look ahead for a opening brace.
	 */
	bool braceAhead;
	if (ps == TokenType.Identifier) {
		auto pos = ps.save();
		while (!ps.eof) {
			if (ps == TokenType.OpenBrace) {
				braceAhead = true;
				break;
			}
			if (ps == TokenType.Semicolon || ps == TokenType.Assign) {
				break;
			}
			ps.get();
		}
		ps.restore(pos);
	}

	ir.Type base;
	if (matchIf(ps, TokenType.Colon)) {
		// Anonymous enum.
		auto succeeded = parseType(ps, /*#out*/base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Enum);
		}
	} else if (braceAhead) {
		// Named enum.
		namedEnum = new ir.Enum();
		namedEnum.loc = origin;
		namedEnum.docComment = ps.comment();
		if (ps != TokenType.Identifier) {
			return unexpectedToken(ps, ir.NodeType.Enum);
		}
		auto nameTok = ps.get();
		namedEnum.name = nameTok.value;
		if (matchIf(ps, TokenType.Colon)) {
			auto succeeded = parseType(ps, /*#out*/namedEnum.base);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Enum);
			}
		} else {
			namedEnum.base = buildStorageType(/*#ref*/ps.peek.loc, ir.StorageType.Kind.Auto, null);
		}
		base = namedEnum;
		output ~= namedEnum;
	}

	if (matchIf(ps, TokenType.OpenBrace)) {
		if (base is null) {
			base = buildPrimitiveType(/*#ref*/ps.peek.loc, ir.PrimitiveType.Kind.Int);
		}
		ir.EnumDeclaration prevEnum;

		// Better error printing.
		if (ps.peek.type == TokenType.CloseBrace) {
			return unexpectedToken(ps, ir.NodeType.Enum);
		}

		while (true) {
			auto succeeded = eatComments(ps);
			if (!succeeded) {
				return succeeded;
			}

			ir.EnumDeclaration ed;
			succeeded = parseEnumDeclaration(ps, /*#out*/ed, false /* standalone */);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Enum);
			}
			ed.prevEnum = prevEnum;
			prevEnum = ed;
			if (namedEnum !is null) {
				if (ed.type !is null) {
					return unexpectedToken(ps, ir.NodeType.Enum);
				}
				ed.type = buildTypeReference(/*#ref*/namedEnum.loc, namedEnum);
				namedEnum.members ~= ed;
			} else {
				if (ed.type is null) {
					ed.type = copyType(base);
				}
				output ~= ed;
			}

			if (matchIf(ps, TokenType.CloseBrace)) {
				break;
			}
			if (matchIf(ps, TokenType.Comma)) {
				succeeded = eatComments(ps);
				if (!succeeded) {
					return succeeded;
				}
				if (matchIf(ps, TokenType.CloseBrace)) {
					break;
				} else {
					continue;
				}
			}

			return unexpectedToken(ps, ir.NodeType.Enum);
		}

	} else {
		if (namedEnum !is null) {
			return unexpectedToken(ps, ir.NodeType.Enum);
		}
		auto comment = ps.comment();
		if (ps != [TokenType.Identifier, TokenType.Assign] && ps != [TokenType.Identifier, TokenType.Colon]) {
			auto succeeded = parseType(ps, /*#out*/base);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Enum);
			}
		} else {
			base = buildStorageType(/*#ref*/ps.peek.loc, ir.StorageType.Kind.Auto, null);
		}

		ir.EnumDeclaration ed;
		auto succeeded = parseEnumDeclaration(ps, /*#out*/ed, true /* standalone */);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Enum);
		}
		ed.docComment = comment;
		if (ps != TokenType.Semicolon) {
			return unexpectedToken(ps, ir.NodeType.Enum);
		}
		ps.get();

		if (ed.type is null) {
			ed.type = base;
		}
		output ~= ed;
	}

	return Succeeded;
}

ParseStatus parseMixinFunction(ParserStream ps, out ir.MixinFunction m)
{
	m = new ir.MixinFunction();
	m.loc = ps.peek.loc;
	m.docComment = ps.comment();

	auto succeeded = match(ps, ir.NodeType.MixinFunction,
		[TokenType.Mixin, TokenType.Function, TokenType.Identifier]);
	if (!succeeded) {
		return succeeded;
	}

	auto nameTok = ps.previous;
	m.name = nameTok.value;
	
	// TODO allow arguments
	succeeded = match(ps, ir.NodeType.MixinTemplate,
		[TokenType.CloseParen, TokenType.OpenBrace]);
	if (!succeeded) {
		return succeeded;
	}
	
	succeeded = parseBlock(ps, /*#out*/m.raw);
	if (!succeeded) {
		return parseFailed(ps, m);
	}

	return Succeeded;
}

ParseStatus parseMixinTemplate(ParserStream ps, out ir.MixinTemplate m)
{
	m = new ir.MixinTemplate();
	m.loc = ps.peek.loc;
	m.docComment = ps.comment();

	auto succeeded = match(ps, ir.NodeType.MixinTemplate,
		[TokenType.Mixin, TokenType.Template, TokenType.Identifier]);
	if (!succeeded) {
		return succeeded;
	}

	auto nameTok = ps.previous;
	m.name = nameTok.value;

	// TODO allow arguments
	succeeded = match(ps, ir.NodeType.MixinTemplate,
		[TokenType.OpenParen, TokenType.CloseParen, TokenType.OpenBrace]);
	if (!succeeded) {
		return succeeded;
	}

	succeeded = parseTopLevelBlock(ps, /*#out*/m.raw, TokenType.CloseBrace);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.MixinTemplate);
	}

	return match(ps, ir.NodeType.MixinTemplate, TokenType.CloseBrace);
}

ParseStatus parseAttribute(ParserStream ps, out ir.Attribute attr, bool noTopLevel=false)
{
	attr = new ir.Attribute();
	attr.loc = ps.peek.loc;

	auto token = ps.get();
	switch (token.type) {
	case TokenType.Extern:
		if (matchIf(ps, TokenType.OpenParen)) {
			if (ps != TokenType.Identifier) {
				return unexpectedToken(ps, attr);
			}
			auto linkageTok = ps.get();
			switch (linkageTok.value) {
			case "C":
				if (matchIf(ps, TokenType.DoublePlus)) {
					attr.kind = ir.Attribute.Kind.LinkageCPlusPlus;
				} else {
					attr.kind = ir.Attribute.Kind.LinkageC;
				}
				break;
			case "D": attr.kind = ir.Attribute.Kind.LinkageD; break;
			case "Windows": attr.kind = ir.Attribute.Kind.LinkageWindows; break;
			case "Pascal": attr.kind = ir.Attribute.Kind.LinkagePascal; break;
			case "System": attr.kind = ir.Attribute.Kind.LinkageSystem; break;
			case "Volt": attr.kind = ir.Attribute.Kind.LinkageVolt; break;
			case "C++": attr.kind = ir.Attribute.Kind.LinkageCPlusPlus; break;
			default:
				return unexpectedToken(ps, attr);
			}
			if (ps != TokenType.CloseParen) {
				return unexpectedToken(ps, attr);
			}
			ps.get();
		} else {
			attr.kind = ir.Attribute.Kind.Extern;
		}
		break;
	case TokenType.Align:
		auto succeeded = checkTokens(ps, ir.NodeType.Attribute,
			[TokenType.OpenParen, TokenType.IntegerLiteral, TokenType.CloseParen]);
		if (!succeeded) {
			return succeeded;
		}
		ps.get();
		auto intTok = ps.get();
		attr.alignAmount = toInt(intTok.value);
		ps.get();
		break;
	case TokenType.At:
		if (ps.peek.type != TokenType.Identifier) {
			return unexpectedToken(ps, attr);
		}
		switch (ps.peek.value) {
		case "disable":
			ps.get();
			attr.kind = ir.Attribute.Kind.Disable;
			break;
		case "property":
			ps.get();
			attr.kind = ir.Attribute.Kind.Property;
			break;
		case "trusted":
			ps.get();
			attr.kind = ir.Attribute.Kind.Trusted;
			break;
		case "system":
			ps.get();
			attr.kind = ir.Attribute.Kind.System;
			break;
		case "safe":
			ps.get();
			attr.kind = ir.Attribute.Kind.Safe;
			break;
		case "loadDynamic":
			ps.get();
			attr.kind = ir.Attribute.Kind.LoadDynamic;
			break;
		case "mangledName":
			ps.get();
			if (ps != TokenType.OpenParen) {
				return unexpectedToken(ps, attr);
			}
			ps.get();
			attr.kind = ir.Attribute.Kind.MangledName;
			ir.Exp e;
			auto succeeded = parseExp(ps, /*#out*/e);
			if (!succeeded) {
				return parseFailed(ps, attr);
			}
			attr.arguments ~= e;
			if (ps != TokenType.CloseParen) {
				return unexpectedToken(ps, attr);
			}
			ps.get();
			break;
		case "label":
			ps.get();
			attr.kind = ir.Attribute.Kind.Label;
			break;
		default:
			auto lower = toLower(ps.peek.value);
			string msg = "valid @ attribute";
			switch (lower) {
			case "label": msg = "@label"; break;
			case "mangledname": msg = "@mangledName"; break;
			case "loaddynamic": msg = "@loadDynamic"; break;
			case "disable": msg = "@disable"; break;
			case "property": msg = "@property"; break;
			case "trusted": msg = "@trusted"; break;
			case "system": msg = "@system"; break;
			case "safe": msg = "@safe"; break;
			default: break;
			}
			return parseExpected(ps, /*#ref*/attr.loc, ir.NodeType.Attribute, msg);
		}
		version (Volt) { if (true) {
			// TODO: Fix Volt's CFG bug.
			break;
		} } else {
			break;
		}
	case TokenType.Deprecated: attr.kind = ir.Attribute.Kind.Deprecated; break;
	case TokenType.Private: attr.kind = ir.Attribute.Kind.Private; break;
	case TokenType.Protected: attr.kind = ir.Attribute.Kind.Protected; break;
	case TokenType.Public: attr.kind = ir.Attribute.Kind.Public; break;
	case TokenType.Export: attr.kind = ir.Attribute.Kind.Export; break;
	case TokenType.Static: attr.kind = ir.Attribute.Kind.Static; break;
	case TokenType.Final: attr.kind = ir.Attribute.Kind.Final; break;
	case TokenType.Synchronized: attr.kind = ir.Attribute.Kind.Synchronized; break;
	case TokenType.Override: attr.kind = ir.Attribute.Kind.Override; break;
	case TokenType.Abstract: attr.kind = ir.Attribute.Kind.Abstract; break;
	case TokenType.Const: attr.kind = ir.Attribute.Kind.Const; break;
	case TokenType.Auto: attr.kind = ir.Attribute.Kind.Auto; break;
	case TokenType.Scope: attr.kind = ir.Attribute.Kind.Scope; break;
	case TokenType.Global: attr.kind = ir.Attribute.Kind.Global; break;
	case TokenType.Local: attr.kind = ir.Attribute.Kind.Local; break;
	case TokenType.Shared: attr.kind = ir.Attribute.Kind.Shared; break;
	case TokenType.Immutable: attr.kind = ir.Attribute.Kind.Immutable; break;
	case TokenType.Inout: attr.kind = ir.Attribute.Kind.Inout; break;
	case TokenType.Nothrow: attr.kind = ir.Attribute.Kind.NoThrow; break;
	case TokenType.Pure: attr.kind = ir.Attribute.Kind.Pure; break;
	default:
		assert(false);
	}

	if (noTopLevel && ps != TokenType.OpenBrace) {
		return Succeeded;
	}

	if (matchIf(ps, TokenType.OpenBrace)) {
		if (ps.comment().length > 0) {
			return docCommentMultiple(ps, /*#ref*/ps.lastDocComment.loc);
		}
		auto succeeded = parseTopLevelBlock(ps, /*#out*/attr.members, TokenType.CloseBrace);
		if (!succeeded) {
			return parseFailed(ps, attr);
		}
		return match(ps, ir.NodeType.Attribute, TokenType.CloseBrace);
	} else if (matchIf(ps, TokenType.Colon)) {
		/* Have the semantic passes apply this attribute as
		 * doing it in the parser would require context.
		 */
		if (ps.comment().length > 0 && !ps.inMultiCommentBlock) {
			return docCommentMultiple(ps, /*#ref*/ps.lastDocComment.loc);
		}
	} else {
		auto succeeded = parseOneTopLevelBlock(ps, /*#out*/attr.members);
		if (!succeeded) {
			return parseFailed(ps, attr);
		}
		if (attr.members !is null &&
		    attr.members.nodes.length == 1 &&
		    attr.members.nodes[0].nodeType == ir.NodeType.Attribute) {
			attr.chain = cast(ir.Attribute)attr.members.nodes[0];
			attr.members.nodes = null;
			attr.members = null;
		}
	}

	return Succeeded;
}

ParseStatus parseCondition(ParserStream ps, out ir.Condition condition)
{
	condition = new ir.Condition();
	condition.loc = ps.peek.loc;

	switch (ps.peek.type) {
	case TokenType.Version:
		condition.kind = ir.Condition.Kind.Version;
		ps.get();
		if (ps != TokenType.OpenParen) {
			return unexpectedToken(ps, condition);
		}
		ps.get();
		break;
	case TokenType.Debug:
		condition.kind = ir.Condition.Kind.Debug;
		ps.get();
		return Succeeded;
	case TokenType.Static:
		condition.kind = ir.Condition.Kind.StaticIf;
		ps.get();
		if (ps != [TokenType.If, TokenType.OpenParen]) {
			return unexpectedToken(ps, condition);
		}
		ps.get();
		ps.get();
		break;
	default:
		return parseExpected(ps, /*#ref*/ps.peek.loc, condition, "'version', 'debug', or 'static'");
	}

	auto succeeded = parseExp(ps, /*#out*/condition.exp);
	if (!succeeded) {
		return parseFailed(ps, condition);
	}

	return match(ps, ir.NodeType.Condition, TokenType.CloseParen);
}

ParseStatus parseConditionTopLevel(ParserStream ps, out ir.ConditionTopLevel ctl)
{
	ctl = new ir.ConditionTopLevel();
	ctl.loc = ps.peek.loc;
	ctl.docComment = ps.comment();

	auto succeeded = parseCondition(ps, /*#out*/ctl.condition);
	if (!succeeded) {
		return parseFailed(ps, ctl);
	}
	if (matchIf(ps, TokenType.Colon)) {
		// Colons are implictly converted into braces; the IR knows nothing of colons.
		succeeded = parseTopLevelBlock(ps, /*#out*/ctl.members, TokenType.CloseBrace);
		if (!succeeded) {
			return parseFailed(ps, ctl);
		}
		return Succeeded;  // Else blocks aren't tied to colon conditionals.
	} else if (matchIf(ps, TokenType.OpenBrace)) {
		succeeded = parseTopLevelBlock(ps, /*#out*/ctl.members, TokenType.CloseBrace);
		if (!succeeded) {
			return parseFailed(ps, ctl);
		}
		if (ps != TokenType.CloseBrace) {
			return unexpectedToken(ps, ctl);
		}
		ps.get();
	} else {
		succeeded = parseOneTopLevelBlock(ps, /*#out*/ctl.members);
		if (!succeeded) {
			return parseFailed(ps, ctl);
		}
	}

	if (matchIf(ps, TokenType.Else)) {
		ctl.elsePresent = true;
		if (matchIf(ps, TokenType.Colon)) {
			// Colons are implictly converted into braces; the IR knows nothing of colons.
			succeeded = parseTopLevelBlock(ps, /*#out*/ctl.members, TokenType.CloseBrace);
			if (!succeeded) {
				return parseFailed(ps, ctl);
			}
		} else if (matchIf(ps, TokenType.OpenBrace)) {
			succeeded = parseTopLevelBlock(ps, /*#out*/ctl._else, TokenType.CloseBrace);
			if (!succeeded) {
				return parseFailed(ps, ctl);
			}
			if (ps != TokenType.CloseBrace) {
				return unexpectedToken(ps, ctl);
			}
			ps.get();
		} else {
			succeeded = parseOneTopLevelBlock(ps, /*#out*/ctl._else);
			if (!succeeded) {
				return parseFailed(ps, ctl);
			}
		}
	}

	return Succeeded;
}
