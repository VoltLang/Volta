// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.toplevel;

import std.conv : to;

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


ir.Module parseModule(TokenStream ts)
{
	auto t = match(ts, TokenType.Module);
	auto qn = parseQualifiedName(ts);
	match(ts, TokenType.Semicolon);

	auto mod = new ir.Module();
	mod.name = qn;

	mod.children = parseTopLevelBlock(ts, TokenType.End, true);

	mod.children.nodes = [
			createImport(mod.location, "defaultsymbols", false),
			createImport(mod.location, "object", true)
		] ~ mod.children.nodes;

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

ir.TopLevelBlock parseOneTopLevelBlock(TokenStream ts, bool inModule = false)
out(result)
{
	assert(result !is null);
}
body
{
	auto tlb = new ir.TopLevelBlock();
	tlb.location = ts.peek.location;

	switch (ts.peek.type) {
		case TokenType.Import:
			tlb.nodes ~= [parseImport(ts, inModule)];
			break;
		case TokenType.Unittest:
			tlb.nodes ~= [parseUnittest(ts)];
			break;
		case TokenType.This:
			tlb.nodes ~= [parseConstructor(ts)];
			break;
		case TokenType.Tilde:  // XXX: Is this unambiguous?
			tlb.nodes ~= [parseDestructor(ts)];
			break;
		case TokenType.Union:
			tlb.nodes ~= [parseUnion(ts)];
			break;
		case TokenType.Struct:
			tlb.nodes ~= [parseStruct(ts)];
			break;
		case TokenType.Class:
			tlb.nodes ~= [parseClass(ts)];
			break;
		case TokenType.Interface:
			tlb.nodes ~= [parseInterface(ts)];
			break;
		case TokenType.Enum:
			tlb.nodes ~= parseEnum(ts);
			break;
		case TokenType.Mixin:
			auto next = ts.lookahead(1).type;
			if (next == TokenType.Function) {
				tlb.nodes ~= [parseMixinFunction(ts)];
			} else if (next == TokenType.Template) {
				tlb.nodes ~= [parseMixinTemplate(ts)];
			} else {
				auto err = ts.lookahead(1);
				throw makeExpected(err.location, "'function' or 'template'");
			}
			break;
		case TokenType.Const:
			if (ts.lookahead(1).type == TokenType.OpenParen) {
				goto default;
			} else {
				goto case;
			}
		case TokenType.At:
			if (ts.lookahead(1).type == TokenType.Interface) {
				tlb.nodes ~= [parseUserAttribute(ts)];
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
			tlb.nodes ~= [parseAttribute(ts, inModule)];
			break;
		case TokenType.Version:
		case TokenType.Debug:
			tlb.nodes ~= [parseConditionTopLevel(ts, inModule)];
			break;
		case TokenType.Static:
			auto next = ts.lookahead(1).type;
			if (next == TokenType.Tilde) {
				goto case TokenType.Tilde;
			} else if (next == TokenType.This) {
				goto case TokenType.This;
			} else if (next == TokenType.Assert) {
				tlb.nodes ~= [parseStaticAssert(ts)];
			} else if (next == TokenType.If) {
				goto case TokenType.Version;
			} else {
				tlb.nodes ~= [parseAttribute(ts, inModule)];
			}
			break;
		case TokenType.Semicolon:
			auto empty = new ir.EmptyTopLevel();
			empty.location = ts.peek.location;
			match(ts, TokenType.Semicolon);
			tlb.nodes ~= [empty];
			break;
		default:
			tlb.nodes ~= parseVariable(ts);
			break;
	}

	return tlb;
}

ir.TopLevelBlock parseTopLevelBlock(TokenStream ts, TokenType end, bool inModule = false)
out(result)
{
	assert(result !is null);
}
body
{
	auto tlb = new ir.TopLevelBlock();
	tlb.location = ts.peek.location;

	while (ts.peek.type != end && ts.peek.type != TokenType.End) {
		auto tmp = parseOneTopLevelBlock(ts, inModule);
		tlb.nodes ~= tmp.nodes;
	}

	return tlb;
}

ir.Node parseImport(TokenStream ts, bool inModule)
{
	if (!inModule) {
		throw makeNonTopLevelImport(ts.peek.location);
	}

	auto _import = new ir.Import();
	_import.location = ts.peek.location;
	match(ts, TokenType.Import);

	if (ts == [TokenType.Identifier, TokenType.Assign]) {
		// import <a = b.c>
		_import.bind = parseIdentifier(ts);
		match(ts, TokenType.Assign);
		_import.name = parseQualifiedName(ts);
	} else {
		// No import bind.
		_import.name = parseQualifiedName(ts);
	}

	// Parse out any aliases.
	if (matchIf(ts, TokenType.Colon)) {
		// import a : <b, c = d>
		bool first = true;
		do {
			if (matchIf(ts, TokenType.Comma)) {
				if (first) {
					throw makeExpected(ts.peek.location, "identifier");
				}
			}
			first = false;
			_import.aliases.length = _import.aliases.length + 1;
			_import.aliases[$ - 1][0] = parseIdentifier(ts);
			if (matchIf(ts, TokenType.Assign)) {
				// import a : b, <c = d>
				_import.aliases[$ - 1][1] = parseIdentifier(ts);
			}
		} while (ts.peek.type == TokenType.Comma);
	}

_exit:
	match(ts, TokenType.Semicolon);
	return _import;
}

ir.Unittest parseUnittest(TokenStream ts)
{
	auto u = new ir.Unittest();
	u.location = ts.peek.location;

	match(ts, TokenType.Unittest);
	u._body = parseBlock(ts);

	return u;
}

ir.Function parseConstructor(TokenStream ts)
{
	auto c = new ir.Function();
	c.kind = ir.Function.Kind.Constructor;
	c.name = "__ctor";

	// XXX: Change to local/global.
	if (matchIf(ts, TokenType.Static)) {
		c.kind = ir.Function.Kind.LocalConstructor;
	}
	//if (matchIf(ts, TokenType.Local)) {
	//	c.kind = ir.Function.Kind.LocalConstructor;
	//} else if (matchIf(ts, TokenType.Global)) {
	//	c.kind = ir.Function.Kind.GlobalConstructor;
	//}

	// Get the location of this.
	c.location = ts.peek.location;

	match(ts, TokenType.This);

	auto pt = new ir.PrimitiveType();
	pt.type = ir.PrimitiveType.Kind.Void;
	pt.location = c.location;

	c.type = new ir.FunctionType();
	c.type.ret = pt;
	auto params = parseParameterList(ts, c.type);
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
		switch (ts.peek.type) {
		case TokenType.In:
			// <in> { }
			if (_in) {
				throw makeMultipleOutBlocks(ts.peek.location);
			}
			_in = true;
			match(ts, TokenType.In);
			c.inContract = parseBlock(ts);
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
				c.outParameter = identTok.value;
				match(ts, TokenType.CloseParen);
			}
			c.outContract = parseBlock(ts);
			break;
		case TokenType.OpenBrace:
		case TokenType.Body:
			if (ts.peek.type == TokenType.Body) {
				ts.get();
			}
			inBlocks = false;
			c._body = parseBlock(ts);
			break;
		default:
			throw makeExpected(ts.peek.location, "block declaration");
		}
	}

	return c;
}

ir.Function parseDestructor(TokenStream ts)
{
	auto d = new ir.Function();
	d.kind = ir.Function.Kind.Destructor;
	d.name = "__dtor";

	// XXX: Change to local/global or local/shared.
	if (matchIf(ts, TokenType.Static)) {
		d.kind = ir.Function.Kind.LocalDestructor;
	}
	//if (matchIf(ts, TokenType.Local)) {
	//	d.kind = ir.Function.Kind.LocalDestructor;
	//} else if (matchIf(ts, TokenType.Global)) {
	//	d.kind = ir.Function.Kind.GlobalDestructor;
	//}

	match(ts, TokenType.Tilde);

	// Get the location of ~this.
	d.location = ts.peek.location - ts.previous.location;

	match(ts, TokenType.This);
	match(ts, TokenType.OpenParen);
	match(ts, TokenType.CloseParen);

	auto pt = new ir.PrimitiveType();
	pt.type = ir.PrimitiveType.Kind.Void;
	pt.location = d.location;

	d.type = new ir.FunctionType();
	d.type.ret = pt;
	d._body = parseBlock(ts);

	return d;
}

ir.Class parseClass(TokenStream ts)
{
	auto c = new ir.Class();
	c.location = ts.peek.location;

	match(ts, TokenType.Class);
	auto nameTok = match(ts, TokenType.Identifier);
	c.name = nameTok.value;
	if (matchIf(ts, TokenType.Colon)) {
		c.parent = parseQualifiedName(ts);
		while (ts.peek.type != TokenType.OpenBrace) {
			match(ts, TokenType.Comma);
			c.interfaces ~= parseQualifiedName(ts);
		}
	}

	match(ts, TokenType.OpenBrace);
	c.members = parseTopLevelBlock(ts, TokenType.CloseBrace);
	match(ts, TokenType.CloseBrace);

	return c;
}

ir._Interface parseInterface(TokenStream ts)
{
	auto i = new ir._Interface();
	i.location = ts.peek.location;

	match(ts, TokenType.Interface);
	auto nameTok = match(ts, TokenType.Identifier);
	i.name = nameTok.value;
	if (matchIf(ts, TokenType.Colon)) {
		while (ts.peek.type != TokenType.OpenBrace) {
			i.interfaces ~= parseQualifiedName(ts);
			if (ts.peek.type != TokenType.OpenBrace) {
				match(ts, TokenType.Comma);
			}
		}
	}

	match(ts, TokenType.OpenBrace);
	i.members = parseTopLevelBlock(ts, TokenType.CloseBrace);
	match(ts, TokenType.CloseBrace);

	return i;
}

ir.Union parseUnion(TokenStream ts)
{
	auto u = new ir.Union();
	u.location = ts.peek.location;

	match(ts, TokenType.Union);
	if (ts.peek.type == TokenType.Identifier) {
		auto nameTok = match(ts, TokenType.Identifier);
		u.name = nameTok.value;
	}

	if (ts.peek.type == TokenType.Semicolon) {
		if (u.name.length == 0) {
			match(ts, TokenType.OpenBrace);
			match(ts, TokenType.Semicolon);
		} else {
			throw makeUnsupported(u.location, "opaque union declarations");
		}
// 		match(ts, TokenType.Semicolon);
	} else {
		match(ts, TokenType.OpenBrace);
		u.members = parseTopLevelBlock(ts, TokenType.CloseBrace);
		match(ts, TokenType.CloseBrace);
	}

	return u;
}

ir.Struct parseStruct(TokenStream ts)
{
	auto s = new ir.Struct();
	s.location = ts.peek.location;

	match(ts, TokenType.Struct);
	if (ts.peek.type == TokenType.Identifier) {
		auto nameTok = match(ts, TokenType.Identifier);
		s.name = nameTok.value;
	}

	if (ts.peek.type == TokenType.Semicolon) {
		throw makeUnsupported(s.location, "opaque struct declarations");
// 		match(ts, TokenType.Semicolon);
	} else {
		match(ts, TokenType.OpenBrace);
		s.members = parseTopLevelBlock(ts, TokenType.CloseBrace);
		match(ts, TokenType.CloseBrace);
	}

	return s;
}

ir.Node[] parseEnum(TokenStream ts)
{
	ir.Node[] output;
	auto origin = ts.peek.location;

	match(ts, TokenType.Enum);

	ir.Enum namedEnum;

	ir.Type base;
	if (matchIf(ts, TokenType.Colon)) {
		base = parseType(ts);
	} else if (ts == [TokenType.Identifier, TokenType.Colon] || ts == [TokenType.Identifier, TokenType.OpenBrace]) {
		// Named enum.
		namedEnum = new ir.Enum();
		namedEnum.location = origin;
		auto nameTok = match(ts, TokenType.Identifier);
		namedEnum.name = nameTok.value;
		if (matchIf(ts, TokenType.Colon)) {
			namedEnum.base = parseType(ts);
		} else {
			namedEnum.base = buildStorageType(ts.peek.location, ir.StorageType.Kind.Auto, null);
		}
		base = namedEnum;
		output ~= namedEnum;
	} else {
		base = buildPrimitiveType(ts.peek.location, ir.PrimitiveType.Kind.Int);
	}
	assert(base !is null);

	if (matchIf(ts, TokenType.OpenBrace)) {
		ir.EnumDeclaration prevEnum;

		// Better error printing.
		if (ts.peek.type == TokenType.CloseBrace) {
			throw makeExpected(origin, "member");
		}

		while (true) {
			auto ed = parseEnumDeclaration(ts);
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

			if (matchIf(ts, TokenType.CloseBrace)) {
				break;
			}
			if (matchIf(ts, TokenType.Comma)) {
				if (matchIf(ts, TokenType.CloseBrace)) {
					break;
				} else {
					continue;
				}
			}

			throw makeExpected(ts.peek.location, "',' or '}'");
		}

	} else {
		if (namedEnum !is null) {
			throw makeExpected(ts.peek.location, "'{'");
		}
		if (ts != [TokenType.Identifier, TokenType.Assign]) {
			base = parseType(ts);
		} else {
			base = buildStorageType(ts.peek.location, ir.StorageType.Kind.Auto, null);
		}

		auto ed = parseEnumDeclaration(ts);
		match(ts, TokenType.Semicolon);

		ed.type = base;
		output ~= ed;
	}

	return output;
}

ir.MixinFunction parseMixinFunction(TokenStream ts)
{
	auto m = new ir.MixinFunction();
	m.location = ts.peek.location;

	match(ts, TokenType.Mixin);
	match(ts, TokenType.Function);
	
	auto nameTok = match(ts, TokenType.Identifier);
	m.name = nameTok.value;
	
	// TODO allow arguments
	match(ts, TokenType.OpenParen);
	match(ts, TokenType.CloseParen);
	
	m.raw = parseBlock(ts);

	return m;
}

ir.MixinTemplate parseMixinTemplate(TokenStream ts)
{
	auto m = new ir.MixinTemplate();
	m.location = ts.peek.location;

	match(ts, TokenType.Mixin);
	match(ts, TokenType.Template);
	
	auto nameTok = match(ts, TokenType.Identifier);
	m.name = nameTok.value;
	
	// TODO allow arguments
	match(ts, TokenType.OpenParen);
	match(ts, TokenType.CloseParen);

	match(ts, TokenType.OpenBrace);
	m.raw = parseTopLevelBlock(ts, TokenType.CloseBrace);
	match(ts, TokenType.CloseBrace);

	return m;
}

ir.Attribute parseAttribute(TokenStream ts, bool inModule = false)
{
	auto attr = new ir.Attribute();
	attr.location = ts.peek.location;

	// Not something we normally do,
	// but in this case makes the code easier.
	auto token = ts.get();

	switch (token.type) {
	case TokenType.Extern:
		if (matchIf(ts, TokenType.OpenParen)) {
			auto linkageTok = match(ts, TokenType.Identifier);
			switch (linkageTok.value) {
			case "C":
				if (matchIf(ts, TokenType.DoublePlus)) {
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
			match(ts, TokenType.CloseParen);
		} else {
			attr.kind = ir.Attribute.Kind.Extern;
		}
		break;
	case TokenType.Align:
		match(ts, TokenType.OpenParen);
		auto intTok = match(ts, TokenType.IntegerLiteral);
		attr.alignAmount = to!int(intTok.value);
		match(ts, TokenType.CloseParen);
		break;
	case TokenType.At:
		if (ts.peek.type != TokenType.Identifier) {
			throw makeExpected(ts.peek.location, "identifier");
		}
		switch (ts.peek.value) {
		case "disable":
			auto nameTok = match(ts, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.Disable;
			break;
		case "property":
			auto nameTok = match(ts, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.Property;
			break;
		case "trusted":
			auto nameTok = match(ts, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.Trusted;
			break;
		case "system":
			auto nameTok = match(ts, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.System;
			break;
		case "safe":
			auto nameTok = match(ts, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.Safe;
			break;
		case "loadDynamic":
			auto nameTok = match(ts, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.LoadDynamic;
			break;
		case "mangledName":
			auto nameTok = match(ts, TokenType.Identifier);
			attr.kind = ir.Attribute.Kind.MangledName;
			match(ts, TokenType.OpenParen);
			attr.arguments ~= parseExp(ts);
			match(ts, TokenType.CloseParen);
			break;
		default:
			attr.kind = ir.Attribute.Kind.UserAttribute;
			attr.userAttributeName = parseQualifiedName(ts);
			if (matchIf(ts, TokenType.OpenParen)) {
				while (ts.peek.type != TokenType.CloseParen) {
					attr.arguments ~= parseExp(ts);
					matchIf(ts, TokenType.Comma);
				}
				match(ts, TokenType.CloseParen);
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

	if (matchIf(ts, TokenType.OpenBrace)) {
		attr.members = parseTopLevelBlock(ts, TokenType.CloseBrace, inModule);
		match(ts, TokenType.CloseBrace);
	} else if (matchIf(ts, TokenType.Colon)) {
		/* Have the semantic passes apply this attribute as
		 * doing it in the parser would require context.
		 */
	} else {
		attr.members = parseOneTopLevelBlock(ts, inModule);
	}

	return attr;
}

ir.StaticAssert parseStaticAssert(TokenStream ts)
{
	auto sa = new ir.StaticAssert();
	sa.location = ts.peek.location;

	match(ts, TokenType.Static);
	match(ts, TokenType.Assert);
	match(ts, TokenType.OpenParen);
	sa.exp = parseExp(ts);
	if (matchIf(ts, TokenType.Comma)) {
		sa.message = parseExp(ts);
	}
	match(ts, TokenType.CloseParen);
	match(ts, TokenType.Semicolon);

	return sa;
}

package ir.Condition parseCondition(TokenStream ts)
{
	auto condition = new ir.Condition();
	condition.location = ts.peek.location;

	switch (ts.peek.type) {
	case TokenType.Version:
		condition.kind = ir.Condition.Kind.Version;
		ts.get();
		match(ts, TokenType.OpenParen);
		break;
	case TokenType.Debug:
		condition.kind = ir.Condition.Kind.Debug;
		ts.get();
		break;
	case TokenType.Static:
		condition.kind = ir.Condition.Kind.StaticIf;
		ts.get();
		match(ts, TokenType.If);
		match(ts, TokenType.OpenParen);
		break;
	default:
		throw makeExpected(ts.peek.location, "'version', 'debug', or 'static'");
	}

	condition.exp = parseExp(ts);
	match(ts, TokenType.CloseParen);

	return condition;
}

ir.ConditionTopLevel parseConditionTopLevel(TokenStream ts, bool inModule = false)
{
	auto ctl = new ir.ConditionTopLevel();
	ctl.location = ts.peek.location;

	ctl.condition = parseCondition(ts);
	if (matchIf(ts, TokenType.Colon)) {
		// Colons are implictly converted into braces; the IR knows nothing of colons.
		ctl.members = parseTopLevelBlock(ts, TokenType.CloseBrace, inModule);
		return ctl;  // Else blocks aren't tied to colon conditionals.
	} else if (matchIf(ts, TokenType.OpenBrace)) {
		ctl.members = parseTopLevelBlock(ts, TokenType.CloseBrace, inModule);
		match(ts, TokenType.CloseBrace);
	} else {
		ctl.members = parseOneTopLevelBlock(ts, inModule);
	}

	if (matchIf(ts, TokenType.Else)) {
		ctl.elsePresent = true;
		if (matchIf(ts, TokenType.Colon)) {
			// Colons are implictly converted into braces; the IR knows nothing of colons.
			ctl.members = parseTopLevelBlock(ts, TokenType.CloseBrace, inModule);
		} else if (matchIf(ts, TokenType.OpenBrace)) {
			ctl._else = parseTopLevelBlock(ts, TokenType.CloseBrace, inModule);
			match(ts, TokenType.CloseBrace);
		} else {
			ctl._else = parseOneTopLevelBlock(ts, inModule);
		}
	}

	return ctl;
}

ir.UserAttribute parseUserAttribute(TokenStream ts)
{
	auto ui = new ir.UserAttribute();
	ui.location = ts.peek.location;

	match(ts, TokenType.At);
	match(ts, TokenType.Interface);
	auto nameTok = match(ts, TokenType.Identifier);
	ui.name = nameTok.value;

	if (ui.name[0] >= 'a' && ui.name[0] <= 'z') {
		throw makeExpected(ts.peek.location, "upper case letter or '_'");
	}

	match(ts, TokenType.OpenBrace);
	while (ts.peek.type != TokenType.CloseBrace) {
		ui.fields ~= parseJustVariable(ts);
	}
	match(ts, TokenType.CloseBrace);

	return ui;
}
