// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.toplevel;

import watt.conv : toInt;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.errors;
import volt.token.stream;
import volt.token.location;

import volt.parser.base;
import volt.parser.declaration;
import volt.parser.statements : parseMixinStatement;
import volt.parser.expression;


ir.Module parseModule(ParserStream ps)
{
	auto initLocation = ps.peek.location;
	ps.pushCommentLevel();
	eatComments(ps);
	auto t = match(ps, TokenType.Module);
	auto qn = parseQualifiedName(ps);
	match(ps, TokenType.Semicolon);

	auto mod = new ir.Module();
	mod.location = initLocation;
	mod.name = qn;
	mod.docComment = ps.comment();
	ps.popCommentLevel();

	mod.children = parseTopLevelBlock(ps, TokenType.End);

	mod.children.nodes = [
			createImport(mod.location, "defaultsymbols", false),
			createImport(mod.location, "object", true)
		] ~ mod.children.nodes;

	if (ps.multiDepth > 0) {
		throw makeExpected(ps.peek.location, "@}");
	}
	return mod;
}

ir.Node createImport(Location location, string name, bool _static)
{
	auto _import = new ir.Import();
	_import.location = location;
	_import.name = new ir.QualifiedName();
	_import.name.location = location;
	_import.name.identifiers ~= new ir.Identifier();
	_import.name.identifiers[0].location = location;
	_import.name.identifiers[0].value = name;
	_import.isStatic = _static;
	return _import;
}

ir.TopLevelBlock parseOneTopLevelBlock(ParserStream ps)
out(result)
{
	assert(result !is null);
}
body
{
	eatComments(ps);
	auto tlb = new ir.TopLevelBlock();
	tlb.location = ps.peek.location;

	switch (ps.peek.type) {
		case TokenType.Import:
			tlb.nodes ~= parseImport(ps);
			break;
		case TokenType.Unittest:
			tlb.nodes ~= parseUnittest(ps);
			break;
		case TokenType.This:
			tlb.nodes ~= parseConstructor(ps);
			break;
		case TokenType.Tilde:  // XXX: Is this unambiguous?
			tlb.nodes ~= parseDestructor(ps);
			break;
		case TokenType.Union:
			tlb.nodes ~= parseUnion(ps);
			break;
		case TokenType.Struct:
			tlb.nodes ~= parseStruct(ps);
			break;
		case TokenType.Class:
			tlb.nodes ~= parseClass(ps);
			break;
		case TokenType.Interface:
			tlb.nodes ~= parseInterface(ps);
			break;
		case TokenType.Enum:
			tlb.nodes ~= parseEnum(ps);
			break;
		case TokenType.Mixin:
			auto next = ps.lookahead(1).type;
			if (next == TokenType.Function) {
				tlb.nodes ~= parseMixinFunction(ps);
			} else if (next == TokenType.Template) {
				tlb.nodes ~= parseMixinTemplate(ps);
			} else {
				auto err = ps.lookahead(1);
				throw makeExpected(err.location, "'function' or 'template'");
			}
			break;
		case TokenType.Const:
			if (ps.lookahead(1).type == TokenType.OpenParen) {
				goto default;
			} else {
				goto case;
			}
		case TokenType.At:
			if (ps.lookahead(1).type == TokenType.Interface) {
				tlb.nodes ~= parseUserAttribute(ps);
				break;
			} else {
				goto case;
			}
		case TokenType.Extern:
		case TokenType.Align:
		case TokenType.Deprecated:
		case TokenType.Private:
		case TokenType.Protected:
		case TokenType.Package:
		case TokenType.Public:
		case TokenType.Export:
		case TokenType.Final:
		case TokenType.Synchronized:
		case TokenType.Override:
		case TokenType.Abstract:
		case TokenType.Global:
		case TokenType.Local:
		case TokenType.Inout:
		case TokenType.Nothrow:
		case TokenType.Pure:
			tlb.nodes ~= parseAttribute(ps);
			break;
		case TokenType.Version:
		case TokenType.Debug:
			tlb.nodes ~= parseConditionTopLevel(ps);
			break;
		case TokenType.Static:
			auto next = ps.lookahead(1).type;
			if (next == TokenType.Tilde) {
				goto case TokenType.Tilde;
			} else if (next == TokenType.This) {
				goto case TokenType.This;
			} else if (next == TokenType.Assert) {
				tlb.nodes ~= parseStaticAssert(ps);
			} else if (next == TokenType.If) {
				goto case TokenType.Version;
			} else {
				tlb.nodes ~= parseAttribute(ps);
			}
			break;
		case TokenType.Semicolon:
			// Just ignore EmptyTopLevel
			match(ps, TokenType.Semicolon);
			break;
		default:
			tlb.nodes ~= parseVariable(ps);
			break;
	}

	return tlb;
}

private bool ifDocCommentsUntilEndThenSkip(ParserStream ps)
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

ir.TopLevelBlock parseTopLevelBlock(ParserStream ps, TokenType end)
out(result)
{
	assert(result !is null);
}
body
{
	auto tlb = new ir.TopLevelBlock();
	tlb.location = ps.peek.location;

	ps.pushCommentLevel();

	while (ps.peek.type != end && ps.peek.type != TokenType.End) {
		if (ifDocCommentsUntilEndThenSkip(ps)) {
			continue;
		}

		auto tmp = parseOneTopLevelBlock(ps);
		if (tmp.nodeType != ir.NodeType.Attribute) {
			ps.popCommentLevel();
			ps.pushCommentLevel();
		}
		tlb.nodes ~= tmp.nodes;
	}

	ps.popCommentLevel();

	return tlb;
}

ir.Node parseImport(ParserStream ps)
{
	auto _import = new ir.Import();
	_import.location = ps.peek.location;
	match(ps, TokenType.Import);

	if (ps == [TokenType.Identifier, TokenType.Assign]) {
		// import <a = b.c>
		_import.bind = parseIdentifier(ps);
		match(ps, TokenType.Assign);
		_import.name = parseQualifiedName(ps);
	} else {
		// No import bind.
		_import.name = parseQualifiedName(ps);
	}

	// Parse out any aliases.
	if (matchIf(ps, TokenType.Colon)) {
		// import a : <b, c = d>
		bool first = true;
		do {
			if (matchIf(ps, TokenType.Comma)) {
				if (first) {
					throw makeExpected(ps.peek.location, "identifier");
				}
			}
			first = false;
			ir.Identifier name, assign;
			name = parseIdentifier(ps);
			if (matchIf(ps, TokenType.Assign)) {
				// import a : b, <c = d>
				assign = parseIdentifier(ps);
			}
			_import.aliases ~= [name, assign];
		} while (ps.peek.type == TokenType.Comma);
	}

	match(ps, TokenType.Semicolon);
	return _import;
}

ir.Unittest parseUnittest(ParserStream ps)
{
	auto u = new ir.Unittest();
	u.location = ps.peek.location;

	match(ps, TokenType.Unittest);
	u._body = parseBlock(ps);

	u.docComment = ps.comment();
	return u;
}

ir.Function parseConstructor(ParserStream ps)
{
	auto c = new ir.Function();
	c.kind = ir.Function.Kind.Constructor;
	c.name = "__ctor";
	c.docComment = ps.comment();

	// XXX: Change to local/global.
	if (matchIf(ps, TokenType.Static)) {
		c.kind = ir.Function.Kind.LocalConstructor;
	}
	//if (matchIf(ps, TokenType.Local)) {
	//	c.kind = ir.Function.Kind.LocalConstructor;
	//} else if (matchIf(ps, TokenType.Global)) {
	//	c.kind = ir.Function.Kind.GlobalConstructor;
	//}

	// Get the location of this.
	c.location = ps.peek.location;

	match(ps, TokenType.This);

	auto pt = new ir.PrimitiveType();
	pt.type = ir.PrimitiveType.Kind.Void;
	pt.location = c.location;

	c.type = new ir.FunctionType();
	c.type.ret = pt;
	auto params = parseParameterList(ps, c.type);
	foreach (i, param; params) {
		c.type.params ~= param.type;
		auto p = new ir.FunctionParam();
		p.location = param.location;
		p.name = param.name;
		p.index = i;
		p.assign = param.assign;
		p.fn = c;
		c.params ~= p;
	}
	bool inBlocks = true;
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
			c.inContract = parseBlock(ps);
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
				c.outParameter = identTok.value;
				match(ps, TokenType.CloseParen);
			}
			c.outContract = parseBlock(ps);
			break;
		case TokenType.OpenBrace:
		case TokenType.Body:
			if (ps.peek.type == TokenType.Body) {
				ps.get();
			}
			inBlocks = false;
			c._body = parseBlock(ps);
			break;
		default:
			throw makeExpected(ps.peek.location, "block declaration");
		}
	}

	return c;
}

ir.Function parseDestructor(ParserStream ps)
{
	auto d = new ir.Function();
	d.kind = ir.Function.Kind.Destructor;
	d.name = "__dtor";
	d.docComment = ps.comment();

	// XXX: Change to local/global or local/shared.
	if (matchIf(ps, TokenType.Static)) {
		d.kind = ir.Function.Kind.LocalDestructor;
	}
	//if (matchIf(ps, TokenType.Local)) {
	//	d.kind = ir.Function.Kind.LocalDestructor;
	//} else if (matchIf(ps, TokenType.Global)) {
	//	d.kind = ir.Function.Kind.GlobalDestructor;
	//}

	match(ps, TokenType.Tilde);

	// Get the location of ~this.
	d.location = ps.peek.location - ps.previous.location;

	match(ps, TokenType.This);
	match(ps, TokenType.OpenParen);
	match(ps, TokenType.CloseParen);

	auto pt = new ir.PrimitiveType();
	pt.type = ir.PrimitiveType.Kind.Void;
	pt.location = d.location;

	d.type = new ir.FunctionType();
	d.type.ret = pt;
	d._body = parseBlock(ps);

	return d;
}

ir.Class parseClass(ParserStream ps)
{
	auto c = new ir.Class();
	c.location = ps.peek.location;
	c.docComment = ps.comment();

	match(ps, TokenType.Class);
	auto nameTok = match(ps, TokenType.Identifier);
	c.name = nameTok.value;
	if (matchIf(ps, TokenType.Colon)) {
		c.parent = parseQualifiedName(ps);
		while (ps.peek.type != TokenType.OpenBrace) {
			match(ps, TokenType.Comma);
			c.interfaces ~= parseQualifiedName(ps);
		}
	}

	match(ps, TokenType.OpenBrace);
	c.members = parseTopLevelBlock(ps, TokenType.CloseBrace);
	match(ps, TokenType.CloseBrace);

	return c;
}

ir._Interface parseInterface(ParserStream ps)
{
	auto i = new ir._Interface();
	i.location = ps.peek.location;
	i.docComment = ps.comment();

	match(ps, TokenType.Interface);
	auto nameTok = match(ps, TokenType.Identifier);
	i.name = nameTok.value;
	if (matchIf(ps, TokenType.Colon)) {
		while (ps.peek.type != TokenType.OpenBrace) {
			i.interfaces ~= parseQualifiedName(ps);
			if (ps.peek.type != TokenType.OpenBrace) {
				match(ps, TokenType.Comma);
			}
		}
	}

	match(ps, TokenType.OpenBrace);
	i.members = parseTopLevelBlock(ps, TokenType.CloseBrace);
	match(ps, TokenType.CloseBrace);

	return i;
}

ir.Union parseUnion(ParserStream ps)
{
	auto u = new ir.Union();
	u.location = ps.peek.location;
	u.docComment = ps.comment();

	match(ps, TokenType.Union);
	if (ps.peek.type == TokenType.Identifier) {
		auto nameTok = match(ps, TokenType.Identifier);
		u.name = nameTok.value;
	} else {
		throw makeUnsupported(u.location, "anonymous union declarations");
	}

	if (ps.peek.type == TokenType.Semicolon) {
		if (u.name.length == 0) {
			match(ps, TokenType.OpenBrace);
			match(ps, TokenType.Semicolon);
		} else {
			throw makeUnsupported(u.location, "opaque union declarations");
		}
// 		match(ps, TokenType.Semicolon);
	} else {
		match(ps, TokenType.OpenBrace);
		u.members = parseTopLevelBlock(ps, TokenType.CloseBrace);
		match(ps, TokenType.CloseBrace);
	}

	return u;
}

ir.Struct parseStruct(ParserStream ps)
{
	auto s = new ir.Struct();
	s.location = ps.peek.location;
	s.docComment = ps.comment();

	match(ps, TokenType.Struct);
	if (ps.peek.type == TokenType.Identifier) {
		auto nameTok = match(ps, TokenType.Identifier);
		s.name = nameTok.value;
	} else {
		throw makeUnsupported(s.location, "anonymous struct declarations");
	}

	if (ps.peek.type == TokenType.Semicolon) {
		throw makeUnsupported(s.location, "opaque struct declarations");
// 		match(ps, TokenType.Semicolon);
	} else {
		match(ps, TokenType.OpenBrace);
		s.members = parseTopLevelBlock(ps, TokenType.CloseBrace);
		match(ps, TokenType.CloseBrace);
	}

	return s;
}

ir.Node[] parseEnum(ParserStream ps)
{
	ir.Node[] output;
	auto origin = ps.peek.location;

	match(ps, TokenType.Enum);

	ir.Enum namedEnum;

	ir.Type base;
	if (matchIf(ps, TokenType.Colon)) {
		base = parseType(ps);
	} else if (ps == [TokenType.Identifier, TokenType.Colon] || ps == [TokenType.Identifier, TokenType.OpenBrace]) {
		// Named enum.
		namedEnum = new ir.Enum();
		namedEnum.location = origin;
		namedEnum.docComment = ps.comment();
		auto nameTok = match(ps, TokenType.Identifier);
		namedEnum.name = nameTok.value;
		if (matchIf(ps, TokenType.Colon)) {
			namedEnum.base = parseType(ps);
		} else {
			namedEnum.base = buildStorageType(ps.peek.location, ir.StorageType.Kind.Auto, null);
		}
		base = namedEnum;
		output ~= namedEnum;
	} else {
		base = buildPrimitiveType(ps.peek.location, ir.PrimitiveType.Kind.Int);
	}
	assert(base !is null);

	if (matchIf(ps, TokenType.OpenBrace)) {
		ir.EnumDeclaration prevEnum;

		// Better error printing.
		if (ps.peek.type == TokenType.CloseBrace) {
			throw makeExpected(origin, "member");
		}

		while (true) {
			eatComments(ps);
			auto ed = parseEnumDeclaration(ps);
			ed.prevEnum = prevEnum;
			prevEnum = ed;
			if (namedEnum !is null) {
				if (ed.type !is null) {
					throw makeExpected(ed.type.location, "non typed member");
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
				eatComments(ps);
				if (matchIf(ps, TokenType.CloseBrace)) {
					break;
				} else {
					continue;
				}
			}

			throw makeExpected(ps.peek.location, "',' or '}'");
		}

	} else {
		if (namedEnum !is null) {
			throw makeExpected(ps.peek.location, "'{'");
		}
		if (ps != [TokenType.Identifier, TokenType.Assign]) {
			base = parseType(ps);
		} else {
			base = buildStorageType(ps.peek.location, ir.StorageType.Kind.Auto, null);
		}

		auto ed = parseEnumDeclaration(ps);
		match(ps, TokenType.Semicolon);

		ed.type = base;
		output ~= ed;
	}

	return output;
}

ir.MixinFunction parseMixinFunction(ParserStream ps)
{
	auto m = new ir.MixinFunction();
	m.location = ps.peek.location;
	m.docComment = ps.comment();

	match(ps, TokenType.Mixin);
	match(ps, TokenType.Function);
	
	auto nameTok = match(ps, TokenType.Identifier);
	m.name = nameTok.value;
	
	// TODO allow arguments
	match(ps, TokenType.OpenParen);
	match(ps, TokenType.CloseParen);
	
	m.raw = parseBlock(ps);

	return m;
}

ir.MixinTemplate parseMixinTemplate(ParserStream ps)
{
	auto m = new ir.MixinTemplate();
	m.location = ps.peek.location;
	m.docComment = ps.comment();

	match(ps, TokenType.Mixin);
	match(ps, TokenType.Template);
	
	auto nameTok = match(ps, TokenType.Identifier);
	m.name = nameTok.value;
	
	// TODO allow arguments
	match(ps, TokenType.OpenParen);
	match(ps, TokenType.CloseParen);

	match(ps, TokenType.OpenBrace);
	m.raw = parseTopLevelBlock(ps, TokenType.CloseBrace);
	match(ps, TokenType.CloseBrace);

	return m;
}

ir.Attribute parseAttribute(ParserStream ps)
{
	auto attr = new ir.Attribute();
	attr.location = ps.peek.location;

	// Not something we normally do,
	// but in this case makes the code easier.
	auto token = ps.get();

	switch (token.type) {
	case TokenType.Extern:
		if (matchIf(ps, TokenType.OpenParen)) {
			auto linkageTok = match(ps, TokenType.Identifier);
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
			default:
				throw makeExpected(linkageTok.location, "'C', 'C++', 'D', 'Windows', 'Pascal', 'System', or 'Volt'");
			}
			match(ps, TokenType.CloseParen);
		} else {
			attr.kind = ir.Attribute.Kind.Extern;
		}
		break;
	case TokenType.Align:
		match(ps, TokenType.OpenParen);
		auto intTok = match(ps, TokenType.IntegerLiteral);
		attr.alignAmount = toInt(intTok.value);
		match(ps, TokenType.CloseParen);
		break;
	case TokenType.At:
		if (ps.peek.type != TokenType.Identifier) {
			throw makeExpected(ps.peek.location, "identifier");
		}
		switch (ps.peek.value) {
		case "disable":
			auto nameTok = match(ps, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.Disable;
			break;
		case "property":
			auto nameTok = match(ps, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.Property;
			break;
		case "trusted":
			auto nameTok = match(ps, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.Trusted;
			break;
		case "system":
			auto nameTok = match(ps, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.System;
			break;
		case "safe":
			auto nameTok = match(ps, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.Safe;
			break;
		case "loadDynamic":
			auto nameTok = match(ps, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.LoadDynamic;
			break;
		case "mangledName":
			auto nameTok = match(ps, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.MangledName;
			match(ps, TokenType.OpenParen);
			attr.arguments ~= parseExp(ps);
			match(ps, TokenType.CloseParen);
			break;
		case "label":
			auto nameTok = match(ps, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.Label;
			break;
		default:
			attr.kind = ir.Attribute.Kind.UserAttribute;
			attr.userAttributeName = parseQualifiedName(ps);
			if (matchIf(ps, TokenType.OpenParen)) {
				while (ps.peek.type != TokenType.CloseParen) {
					attr.arguments ~= parseExp(ps);
					matchIf(ps, TokenType.Comma);
				}
				match(ps, TokenType.CloseParen);
			}
			break;
		}
		break;
	case TokenType.Deprecated: attr.kind = ir.Attribute.Kind.Deprecated; break;
	case TokenType.Private: attr.kind = ir.Attribute.Kind.Private; break;
	case TokenType.Protected: attr.kind = ir.Attribute.Kind.Protected; break;
	case TokenType.Package: attr.kind = ir.Attribute.Kind.Package; break;
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

	if (matchIf(ps, TokenType.OpenBrace)) {
		if (ps.comment().length > 0) {
			throw makeDocCommentAppliesToMultiple(ps.lastDocComment.location);
		}
		attr.members = parseTopLevelBlock(ps, TokenType.CloseBrace);
		match(ps, TokenType.CloseBrace);
	} else if (matchIf(ps, TokenType.Colon)) {
		/* Have the semantic passes apply this attribute as
		 * doing it in the parser would require context.
		 */
		if (ps.comment().length > 0 && !ps.inMultiCommentBlock) {
			throw makeDocCommentAppliesToMultiple(ps.lastDocComment.location);
		}
	} else {
		attr.members = parseOneTopLevelBlock(ps);
		if (attr.members !is null &&
		    attr.members.nodes.length == 1 &&
		    attr.members.nodes[0].nodeType == ir.NodeType.Attribute) {
			attr.chain = cast(ir.Attribute)attr.members.nodes[0];
			attr.members.nodes = null;
			attr.members = null;
		}
	}

	return attr;
}

ir.StaticAssert parseStaticAssert(ParserStream ps)
{
	auto sa = new ir.StaticAssert();
	sa.location = ps.peek.location;
	sa.docComment = ps.comment();

	match(ps, TokenType.Static);
	match(ps, TokenType.Assert);
	match(ps, TokenType.OpenParen);
	sa.exp = parseExp(ps);
	if (matchIf(ps, TokenType.Comma)) {
		sa.message = parseExp(ps);
	}
	match(ps, TokenType.CloseParen);
	match(ps, TokenType.Semicolon);

	return sa;
}

package ir.Condition parseCondition(ParserStream ps)
{
	auto condition = new ir.Condition();
	condition.location = ps.peek.location;

	switch (ps.peek.type) {
	case TokenType.Version:
		condition.kind = ir.Condition.Kind.Version;
		ps.get();
		match(ps, TokenType.OpenParen);
		break;
	case TokenType.Debug:
		condition.kind = ir.Condition.Kind.Debug;
		ps.get();
		return condition;
	case TokenType.Static:
		condition.kind = ir.Condition.Kind.StaticIf;
		ps.get();
		match(ps, TokenType.If);
		match(ps, TokenType.OpenParen);
		break;
	default:
		throw makeExpected(ps.peek.location, "'version', 'debug', or 'static'");
	}

	condition.exp = parseExp(ps);
	match(ps, TokenType.CloseParen);

	return condition;
}

ir.ConditionTopLevel parseConditionTopLevel(ParserStream ps)
{
	auto ctl = new ir.ConditionTopLevel();
	ctl.location = ps.peek.location;
	ctl.docComment = ps.comment();

	ctl.condition = parseCondition(ps);
	if (matchIf(ps, TokenType.Colon)) {
		// Colons are implictly converted into braces; the IR knows nothing of colons.
		ctl.members = parseTopLevelBlock(ps, TokenType.CloseBrace);
		return ctl;  // Else blocks aren't tied to colon conditionals.
	} else if (matchIf(ps, TokenType.OpenBrace)) {
		ctl.members = parseTopLevelBlock(ps, TokenType.CloseBrace);
		match(ps, TokenType.CloseBrace);
	} else {
		ctl.members = parseOneTopLevelBlock(ps);
	}

	if (matchIf(ps, TokenType.Else)) {
		ctl.elsePresent = true;
		if (matchIf(ps, TokenType.Colon)) {
			// Colons are implictly converted into braces; the IR knows nothing of colons.
			ctl.members = parseTopLevelBlock(ps, TokenType.CloseBrace);
		} else if (matchIf(ps, TokenType.OpenBrace)) {
			ctl._else = parseTopLevelBlock(ps, TokenType.CloseBrace);
			match(ps, TokenType.CloseBrace);
		} else {
			ctl._else = parseOneTopLevelBlock(ps);
		}
	}

	return ctl;
}

ir.UserAttribute parseUserAttribute(ParserStream ps)
{
	auto ui = new ir.UserAttribute();
	ui.location = ps.peek.location;
	ui.docComment = ps.comment();

	match(ps, TokenType.At);
	match(ps, TokenType.Interface);
	auto nameTok = match(ps, TokenType.Identifier);
	ui.name = nameTok.value;

	if (ui.name[0] >= 'a' && ui.name[0] <= 'z') {
		throw makeExpected(ps.peek.location, "upper case letter or '_'");
	}

	match(ps, TokenType.OpenBrace);
	while (ps.peek.type != TokenType.CloseBrace) {
		ui.fields ~= parseJustVariable(ps);
	}
	match(ps, TokenType.CloseBrace);

	return ui;
}
