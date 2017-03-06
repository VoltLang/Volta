// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.toplevel;

import watt.conv : toInt, toLower;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.exceptions;
import volt.errors;
import volt.token.stream;
import volt.token.location;
import volt.token.token : TokenType;

import volt.parser.base;
import volt.parser.declaration;
public import volt.parser.statements : parseMixinStatement;
import volt.parser.expression;


ParseStatus parseModule(ParserStream ps, out ir.Module mod)
{
	auto initLocation = ps.peek.location;
	ps.pushCommentLevel();
	auto succeeded = eatComments(ps);
	if (!succeeded) {
		return succeeded;
	}
	if (ps.peek.type == TokenType.Module) {
		auto t = ps.get();

		ir.QualifiedName qn;
		succeeded = parseQualifiedName(ps, qn);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Module);
		}

		if (ps.peek.type != TokenType.Semicolon) {
			return unexpectedToken(ps, ir.NodeType.Module);
		}
		ps.get();

		mod = new ir.Module();
		mod.location = initLocation;
		mod.name = qn;
		mod.docComment = ps.comment();
	} else {
		mod = new ir.Module();
		mod.location = initLocation;
		mod.name = buildQualifiedName(mod.location, mod.location.filename);
		mod.docComment = ps.comment();
		mod.isAnonymous = true;
	}
	ps.popCommentLevel();

	succeeded = parseTopLevelBlock(ps, mod.children, TokenType.End);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Module);
	}

	if (ps.multiDepth > 0) {
		return parseExpected(ps, ps.peek.location, ir.NodeType.Module, "@}");
	}

	// Don't include the default modules in themselves.
	// Maybe move to gather or import resolver?
	if (mod.name.identifiers.length == 3 &&
	    mod.name.identifiers[0].value == "core" &&
	    mod.name.identifiers[0].value == "compiler" &&
	    mod.name.identifiers[0].value == "defaultsymbols") {
		return Succeeded;
	}

	mod.children.nodes = [
			createImport(mod.location, "core", "compiler", "defaultsymbols")
		] ~ mod.children.nodes;

	return Succeeded;
}

ir.Node createImport(Location location, string[] names...)
{
	auto _import = new ir.Import();
	_import.location = location;
	_import.name = new ir.QualifiedName();
	_import.name.location = location;
	foreach (i, name; names) {
		_import.name.identifiers ~= new ir.Identifier();
		_import.name.identifiers[i].location = location;
		_import.name.identifiers[i].value = name;
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
	tlb.location = ps.peek.location;

	auto sink = new NodeSink();

	switch (ps.peek.type) {
		case TokenType.Import:
			ir.Import _import;
			succeeded = parseImport(ps, _import);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(_import);
			break;
		case TokenType.Unittest:
			ir.Unittest u;
			succeeded = parseUnittest(ps, u);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(u);
			break;
		case TokenType.This:
			ir.Function c;
			succeeded = parseConstructor(ps, c);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(c);
			break;
		case TokenType.Tilde:  // XXX: Is this unambiguous?
			ir.Function d;
			succeeded = parseDestructor(ps, d);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(d);
			break;
		case TokenType.Union:
			ir.Union u;
			succeeded = parseUnion(ps, u);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(u);
			break;
		case TokenType.Struct:
			ir.Struct s;
			succeeded = parseStruct(ps, s);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(s);
			break;
		case TokenType.Class:
			ir.Class c;
			succeeded = parseClass(ps, c);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(c);
			break;
		case TokenType.Interface:
			ir._Interface i;
			succeeded = parseInterface(ps, i);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(i);
			break;
		case TokenType.Enum:
			ir.Node[] nodes;
			succeeded = parseEnum(ps, nodes);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.pushNodes(nodes);
			break;
		case TokenType.Mixin:
			auto next = ps.lookahead(1).type;
			if (next == TokenType.Function) {
				ir.MixinFunction m;
				succeeded = parseMixinFunction(ps, m);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.TopLevelBlock);
				}
				sink.push(m);
			} else if (next == TokenType.Template) {
				ir.MixinTemplate m;
				succeeded = parseMixinTemplate(ps, m);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.TopLevelBlock);
				}
				sink.push(m);
			} else {
				return unexpectedToken(ps, ir.NodeType.TopLevelBlock);
			}
			break;
		case TokenType.Const:
			if (ps.lookahead(1).type == TokenType.OpenParen) {
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
			succeeded = parseAttribute(ps, a);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(a);
			break;
		case TokenType.Global:
		case TokenType.Local:
			auto next = ps.lookahead(1).type;
			if (next == TokenType.Tilde) {
				goto case TokenType.Tilde;
			} else if (next == TokenType.This) {
				goto case TokenType.This;
			}
			goto case TokenType.Pure; // To attribute parsing.
		case TokenType.Version:
		case TokenType.Debug:
			ir.ConditionTopLevel c;
			succeeded = parseConditionTopLevel(ps, c);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.TopLevelBlock);
			}
			sink.push(c);
			break;
		case TokenType.Static:
			auto next = ps.lookahead(1).type;
			if (next == TokenType.Tilde) {
				goto case TokenType.Tilde;
			} else if (next == TokenType.This) {
				goto case TokenType.This;
			} else if (next == TokenType.Assert) {
				ir.StaticAssert s;
				succeeded = parseStaticAssert(ps, s);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.TopLevelBlock);
				}
				sink.push(s);
			} else if (next == TokenType.If) {
				goto case TokenType.Version;
			} else {
				ir.Attribute a;
				succeeded = parseAttribute(ps, a);
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
	do {
		tt = ps.lookahead(n++).type;
	} while (tt == TokenType.DocComment);
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
	tlb.location = ps.peek.location;

	ps.pushCommentLevel();

	while (ps.peek.type != end && ps.peek.type != TokenType.End) {
		ir.TopLevelBlock tmp;
		auto succeeded = parseOneTopLevelBlock(ps, tmp);
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
	_import.location = ps.peek.location;
	_import.access = ir.Access.Private;
	auto succeeded = match(ps, _import, TokenType.Import);
	if (!succeeded) {
		return succeeded;
	}

	if (ps == [TokenType.Identifier, TokenType.Assign]) {
		// import <a = b.c>
		succeeded = parseIdentifier(ps, _import.bind);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Import);
		}
		if (ps.peek.type != TokenType.Assign) {
			return unexpectedToken(ps, ir.NodeType.Import);
		}
		ps.get();
		succeeded = parseQualifiedName(ps, _import.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Import);
		}
	} else {
		// No import bind.
		succeeded = parseQualifiedName(ps, _import.name);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Import);
		}
	}

	// Parse out any aliases.
	if (matchIf(ps, TokenType.Colon)) {
		// import a : <b, c = d>
		bool first = true;
		do {
			if (matchIf(ps, TokenType.Comma)) {
				if (first) {
					return parseExpected(ps, ps.peek.location, ir.NodeType.Import, "identifier");
				}
			}
			first = false;
			ir.Identifier name, assign;
			succeeded = parseIdentifier(ps, name);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Import);
			}
			if (ps.peek.type == TokenType.Assign) {
				ps.get();
				succeeded = parseIdentifier(ps, assign);
				if (!succeeded) {
					return parseFailed(ps, ir.NodeType.Import);
				}
			}
			_import.aliases ~= [name, assign];
		} while (ps.peek.type == TokenType.Comma);
	}

	return match(ps, ir.NodeType.Import, TokenType.Semicolon);
}

ParseStatus parseUnittest(ParserStream ps, out ir.Unittest u)
{
	u = new ir.Unittest();
	u.location = ps.peek.location;

	if (ps.peek.type != TokenType.Unittest) {
		return unexpectedToken(ps, ir.NodeType.Unittest);
	}
	ps.get();
	auto succeeded = parseBlock(ps, u._body);
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

	// Get the location of this.
	c.location = ps.peek.location;

	if (ps.peek.type != TokenType.This) {
		return unexpectedToken(ps, ir.NodeType.Function);
	}
	ps.get();

	auto pt = new ir.PrimitiveType();
	pt.type = ir.PrimitiveType.Kind.Void;
	pt.location = c.location;

	c.type = new ir.FunctionType();
	c.type.ret = pt;

	ir.Variable[] params;
	bool colonDeclaration = isColonDeclaration(ps);
	auto succeeded = parseParameterList(ps, params, c.type);
	if (params.length > 0 && !colonDeclaration) {
		warningOldStyleFunction(c.location, ps.settings);
	}
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Function, ir.NodeType.FunctionParam);
	}

	foreach (i, param; params) {
		c.type.params ~= param.type;
		c.type.isArgRef ~= false;
		c.type.isArgOut ~= false;
		auto p = new ir.FunctionParam();
		p.location = param.location;
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
				return parseExpected(ps, ps.peek.location, c, "one in block");
			}
			_in = true;
			if (ps != TokenType.In) {
				return unexpectedToken(ps, c);
			}
			ps.get();
			succeeded = parseBlock(ps, c.inContract);
			if (!succeeded) {
				return parseFailed(ps, c);
			}
			break;
		case TokenType.Out:
			// <out>
			if (_out) {
				return parseExpected(ps, ps.peek.location, c, "one out block");
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
			succeeded = parseBlock(ps, c.outContract);
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
			auto succeeded2 = parseBlock(ps, c._body);
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

	// Get the location of ~this.
	d.location = ps.peek.location - ps.previous.location;

	auto succeeded = match(ps, ir.NodeType.Function,
		[TokenType.This, TokenType.OpenParen, TokenType.CloseParen]);
	if (!succeeded) {
		return succeeded;
	}

	auto pt = new ir.PrimitiveType();
	pt.type = ir.PrimitiveType.Kind.Void;
	pt.location = d.location;

	d.type = new ir.FunctionType();
	d.type.ret = pt;
	succeeded = parseBlock(ps, d._body);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Function, ir.NodeType.BlockStatement);
	}

	return Succeeded;
}

ParseStatus parseClass(ParserStream ps, out ir.Class c)
{
	c = new ir.Class();
	c.location = ps.peek.location;
	c.docComment = ps.comment();

	auto succeeded = match(ps, ir.NodeType.Class,
		[TokenType.Class, TokenType.Identifier]);
	if (!succeeded) {
		return succeeded;
	}

	auto nameTok = ps.previous;
	c.name = nameTok.value;
	if (matchIf(ps, TokenType.Colon)) {
		succeeded = parseQualifiedName(ps, c.parent);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Class, ir.NodeType.QualifiedName);
		}
		while (ps.peek.type != TokenType.OpenBrace) {
			if (ps.peek.type != TokenType.Comma) {
				return unexpectedToken(ps, ir.NodeType.Class);
			}
			ps.get();
			ir.QualifiedName i;
			succeeded = parseQualifiedName(ps, i);
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
	succeeded = parseTopLevelBlock(ps, c.members, TokenType.CloseBrace);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Class, ir.NodeType.TopLevelBlock);
	}

	return match(ps, ir.NodeType.Class, TokenType.CloseBrace);
}

ParseStatus parseInterface(ParserStream ps, out ir._Interface i)
{
	i = new ir._Interface();
	i.location = ps.peek.location;
	i.docComment = ps.comment();

	auto succeeded = match(ps, ir.NodeType.Interface,
		[TokenType.Interface, TokenType.Identifier]);
	if (!succeeded) {
		return succeeded;
	}

	auto nameTok = ps.previous;
	i.name = nameTok.value;
	if (matchIf(ps, TokenType.Colon)) {
		while (ps.peek.type != TokenType.OpenBrace) {
			ir.QualifiedName q;
			succeeded = parseQualifiedName(ps, q);
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
	succeeded = parseTopLevelBlock(ps, i.members, TokenType.CloseBrace);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.Interface, ir.NodeType.TopLevelBlock);
	}

	return match(ps, ir.NodeType.Interface, TokenType.CloseBrace);
}

ParseStatus parseUnion(ParserStream ps, out ir.Union u)
{
	u = new ir.Union();
	u.location = ps.peek.location;
	u.docComment = ps.comment();

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
		auto succeeded = parseTopLevelBlock(ps, u.members, TokenType.CloseBrace);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Union);
		}

		return match(ps, ir.NodeType.Union, TokenType.CloseBrace);
	}

	return Succeeded;
}

ParseStatus parseStruct(ParserStream ps, out ir.Struct s)
{
	s = new ir.Struct();
	s.location = ps.peek.location;
	s.docComment = ps.comment();

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

	if (ps.peek.type == TokenType.Semicolon) {
		return unsupportedFeature(ps, s, "opaque struct declarations");
	} else {
		if (ps.peek.type != TokenType.OpenBrace) {
			return unexpectedToken(ps, ir.NodeType.Struct);
		}
		ps.get();
		auto succeeded = parseTopLevelBlock(ps, s.members, TokenType.CloseBrace);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Struct);
		}

		return match(ps, ir.NodeType.Struct, TokenType.CloseBrace);
	}

	version (Volt) assert(false); // If
}

ParseStatus parseEnum(ParserStream ps, out ir.Node[] output)
{
	auto origin = ps.peek.location;

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
		while (ps != TokenType.End) {
			if (ps == TokenType.OpenBrace) {
				braceAhead = true;
				break;
			}
			if (ps == TokenType.Semicolon) {
				break;
			}
			ps.get();
		}
		ps.restore(pos);
	}

	ir.Type base;
	if (matchIf(ps, TokenType.Colon)) {
		// Anonymous enum.
		auto succeeded = parseType(ps, base);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Enum);
		}
	} else if (braceAhead) {
		// Named enum.
		namedEnum = new ir.Enum();
		namedEnum.location = origin;
		namedEnum.docComment = ps.comment();
		if (ps != TokenType.Identifier) {
			return unexpectedToken(ps, ir.NodeType.Enum);
		}
		auto nameTok = ps.get();
		namedEnum.name = nameTok.value;
		if (matchIf(ps, TokenType.Colon)) {
			auto succeeded = parseType(ps, namedEnum.base);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Enum);
			}
		} else {
			namedEnum.base = buildStorageType(ps.peek.location, ir.StorageType.Kind.Auto, null);
		}
		base = namedEnum;
		output ~= namedEnum;
	}

	if (matchIf(ps, TokenType.OpenBrace)) {
		if (base is null) {
			base = buildPrimitiveType(ps.peek.location, ir.PrimitiveType.Kind.Int);
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
			succeeded = parseEnumDeclaration(ps, ed);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Enum);
			}
			ed.prevEnum = prevEnum;
			prevEnum = ed;
			if (namedEnum !is null) {
				if (ed.type !is null) {
					return unexpectedToken(ps, ir.NodeType.Enum);
				}
				ed.type = buildTypeReference(namedEnum.location, namedEnum);
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
		if (ps != [TokenType.Identifier, TokenType.Assign] && ps != [TokenType.Identifier, TokenType.Colon]) {
			auto succeeded = parseType(ps, base);
			if (!succeeded) {
				return parseFailed(ps, ir.NodeType.Enum);
			}
		} else {
			base = buildStorageType(ps.peek.location, ir.StorageType.Kind.Auto, null);
		}

		ir.EnumDeclaration ed;
		auto succeeded = parseEnumDeclaration(ps, ed);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.Enum);
		}
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
	m.location = ps.peek.location;
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
	
	succeeded = parseBlock(ps, m.raw);
	if (!succeeded) {
		return parseFailed(ps, m);
	}

	return Succeeded;
}

ParseStatus parseMixinTemplate(ParserStream ps, out ir.MixinTemplate m)
{
	m = new ir.MixinTemplate();
	m.location = ps.peek.location;
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

	succeeded = parseTopLevelBlock(ps, m.raw, TokenType.CloseBrace);
	if (!succeeded) {
		return parseFailed(ps, ir.NodeType.MixinTemplate);
	}

	return match(ps, ir.NodeType.MixinTemplate, TokenType.CloseBrace);
}

ParseStatus parseAttribute(ParserStream ps, out ir.Attribute attr, bool noTopLevel=false)
{
	attr = new ir.Attribute();
	attr.location = ps.peek.location;

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
			auto succeeded = parseExp(ps, e);
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
			return parseExpected(ps, attr.location, ir.NodeType.Attribute, msg);
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
			return docCommentMultiple(ps, ps.lastDocComment.location);
		}
		auto succeeded = parseTopLevelBlock(ps, attr.members, TokenType.CloseBrace);
		if (!succeeded) {
			return parseFailed(ps, attr);
		}
		return match(ps, ir.NodeType.Attribute, TokenType.CloseBrace);
	} else if (matchIf(ps, TokenType.Colon)) {
		/* Have the semantic passes apply this attribute as
		 * doing it in the parser would require context.
		 */
		if (ps.comment().length > 0 && !ps.inMultiCommentBlock) {
			return docCommentMultiple(ps, ps.lastDocComment.location);
		}
	} else {
		auto succeeded = parseOneTopLevelBlock(ps, attr.members);
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

ParseStatus parseStaticAssert(ParserStream ps, out ir.StaticAssert sa)
{
	sa = new ir.StaticAssert();
	sa.location = ps.peek.location;
	sa.docComment = ps.comment();

	auto succeeded = match(ps, ir.NodeType.StaticAssert,
		[TokenType.Static, TokenType.Assert, TokenType.OpenParen]);
	if (!succeeded) {
		return succeeded;
	}

	succeeded = parseExp(ps, sa.exp);
	if (!succeeded) {
		return parseFailed(ps, sa);
	}
	if (matchIf(ps, TokenType.Comma)) {
		succeeded = parseExp(ps, sa.message);
		if (!succeeded) {
			return parseFailed(ps, sa);
		}
	}

	return match(ps, ir.NodeType.StaticAssert,
		[TokenType.CloseParen, TokenType.Semicolon]);
}

ParseStatus parseCondition(ParserStream ps, out ir.Condition condition)
{
	condition = new ir.Condition();
	condition.location = ps.peek.location;

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
		return parseExpected(ps, ps.peek.location, condition, "'version', 'debug', or 'static'");
	}

	auto succeeded = parseExp(ps, condition.exp);
	if (!succeeded) {
		return parseFailed(ps, condition);
	}

	return match(ps, ir.NodeType.Condition, TokenType.CloseParen);
}

ParseStatus parseConditionTopLevel(ParserStream ps, out ir.ConditionTopLevel ctl)
{
	ctl = new ir.ConditionTopLevel();
	ctl.location = ps.peek.location;
	ctl.docComment = ps.comment();

	auto succeeded = parseCondition(ps, ctl.condition);
	if (!succeeded) {
		return parseFailed(ps, ctl);
	}
	if (matchIf(ps, TokenType.Colon)) {
		// Colons are implictly converted into braces; the IR knows nothing of colons.
		succeeded = parseTopLevelBlock(ps, ctl.members, TokenType.CloseBrace);
		if (!succeeded) {
			return parseFailed(ps, ctl);
		}
		return Succeeded;  // Else blocks aren't tied to colon conditionals.
	} else if (matchIf(ps, TokenType.OpenBrace)) {
		succeeded = parseTopLevelBlock(ps, ctl.members, TokenType.CloseBrace);
		if (!succeeded) {
			return parseFailed(ps, ctl);
		}
		if (ps != TokenType.CloseBrace) {
			return unexpectedToken(ps, ctl);
		}
		ps.get();
	} else {
		succeeded = parseOneTopLevelBlock(ps, ctl.members);
		if (!succeeded) {
			return parseFailed(ps, ctl);
		}
	}

	if (matchIf(ps, TokenType.Else)) {
		ctl.elsePresent = true;
		if (matchIf(ps, TokenType.Colon)) {
			// Colons are implictly converted into braces; the IR knows nothing of colons.
			succeeded = parseTopLevelBlock(ps, ctl.members, TokenType.CloseBrace);
			if (!succeeded) {
				return parseFailed(ps, ctl);
			}
		} else if (matchIf(ps, TokenType.OpenBrace)) {
			succeeded = parseTopLevelBlock(ps, ctl._else, TokenType.CloseBrace);
			if (!succeeded) {
				return parseFailed(ps, ctl);
			}
			if (ps != TokenType.CloseBrace) {
				return unexpectedToken(ps, ctl);
			}
			ps.get();
		} else {
			succeeded = parseOneTopLevelBlock(ps, ctl._else);
			if (!succeeded) {
				return parseFailed(ps, ctl);
			}
		}
	}

	return Succeeded;
}
