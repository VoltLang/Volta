// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.toplevel;

import std.conv : to;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.token.stream;

import volt.parser.base;
import volt.parser.declaration;
import volt.parser.expression;


ir.Module parseModule(TokenStream ts)
{
	auto t = match(ts, TokenType.Module);
	auto qn = parseQualifiedName(ts);
	match(ts, TokenType.Semicolon);

	auto mod = new ir.Module();
	mod.name = qn;

	while(ts != TokenType.End) {
		mod.children ~= parseTopLevelDecl(ts, true);
	}

	return mod;
}

ir.Node[] parseTopLevelDecl(TokenStream ts, bool inModule = false)
out(result)
{
	assert(result !is null);
}
body
{
	auto t = ts.peek;
	auto type = t.type;

	switch (ts.peek.type) {
	case TokenType.Import:
		return [parseImport(ts, inModule)];
	case TokenType.Unittest:
		return [parseUnittest(ts)];
	case TokenType.This:
		return [parseConstructor(ts)];
	case TokenType.Tilde:  // XXX: Is this unambiguous?
		return [parseDestructor(ts)];
	case TokenType.Struct:
		return [parseStruct(ts)];
	case TokenType.Class:
		return [parseClass(ts)];
	case TokenType.Interface:
		return [parseInterface(ts)];
	case TokenType.Enum:
		return [parseEnum(ts)];
	case TokenType.Extern:
	case TokenType.Align:
	case TokenType.At:
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
	case TokenType.Const:
	case TokenType.Auto:
	case TokenType.Scope:
	case TokenType.Global:
	case TokenType.Local:
	case TokenType.Shared:
	case TokenType.Immutable:
	case TokenType.Inout:
		return [parseAttribute(ts, inModule)];
	case TokenType.Version:
	case TokenType.Debug:
		return [parseConditionTopLevel(ts, inModule)];
	case TokenType.Static:
		auto next = ts.lookahead(1).type;
		if (next == TokenType.Tilde) {
			goto case TokenType.Tilde;
		} else if (next == TokenType.This) {
			goto case TokenType.This;
		} else if (next == TokenType.Assert) {
			return [parseStaticAssert(ts)];
		} else if (next == TokenType.If) {
			goto case TokenType.Version;
		} else {
			return [parseAttribute(ts)];
		}
	case TokenType.Semicolon:
		auto empty = new ir.EmptyTopLevel();
		empty.location = ts.peek.location;
		match(ts, TokenType.Semicolon);
		return [empty];
	default:
		return parseVariable(ts);
	}
}

ir.Node parseImport(TokenStream ts, bool inModule)
{
	if (!inModule) {
		throw new CompilerError(ts.peek.location,
		                        "Imports only allowed in top scope");
	}

	auto _import = new ir.Import();
	_import.location = ts.peek.location;
	match(ts, TokenType.Import);

	if (ts == [TokenType.Identifier, TokenType.Assign]) {
		// import <a = b.c>
		_import.bind = parseIdentifier(ts);
		match(ts, TokenType.Assign);
		_import.names ~= parseQualifiedName(ts);
	} else {
		// No import bind.
		_import.names ~= parseQualifiedName(ts);
		while (ts.peek.type == TokenType.Comma) {
			match(ts, TokenType.Comma);
			_import.names ~= parseQualifiedName(ts);
		}
		if (_import.names.length > 1) {
			// import a, b.c, d;
			goto _exit;
		}
	}

	// Only one import, so we can check for aliases.
	assert(_import.names.length == 1);
	if (matchIf(ts, TokenType.Colon)) {
		// import a : <b, c = d>
		bool first = true;
		do {
			if (matchIf(ts, TokenType.Comma)) {
				if (first) {
					throw new CompilerError(ts.peek.location, "expected identifier, not ','.");
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
	c.type.params = parseParameterList(ts);
	c._body = parseBlock(ts);

	return c;
}

ir.Function parseDestructor(TokenStream ts)
{
	auto d = new ir.Function();
	d.kind = ir.Function.Kind.Destructor;

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
	while (ts.peek.type != TokenType.CloseBrace) {
		c.members ~= parseTopLevelDecl(ts);
	}
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
	while (ts.peek.type != TokenType.CloseBrace) {
		i.members ~= parseTopLevelDecl(ts);
	}
	match(ts, TokenType.CloseBrace);

	return i;
}

ir.Struct parseStruct(TokenStream ts)
{
	auto s = new ir.Struct();
	s.location = ts.peek.location;

	match(ts, TokenType.Struct);
	auto nameTok = match(ts, TokenType.Identifier);
	s.name = nameTok.value;

	if (ts.peek.type == TokenType.Semicolon) {
		match(ts, TokenType.Semicolon);
	} else {
		match(ts, TokenType.OpenBrace);
		while (ts.peek.type != TokenType.CloseBrace) {
			s.members ~= parseTopLevelDecl(ts);
		}
		match(ts, TokenType.CloseBrace);
	}

	return s;
}

// eg "enum int a = 3;"
private ir.Enum tryParseManifestConstant(TokenStream ts)
{
	auto e = new ir.Enum();
	e.location = ts.peek.location;
	auto member = ir.Enum.Member();
	member.location = ts.peek.location;

	match(ts, TokenType.Enum);
	e.base = parseType(ts);
	auto nameTok = match(ts, TokenType.Identifier);
	member.name = nameTok.value;
	match(ts, TokenType.Assign);
	member.init = parseAssignExp(ts);
	match(ts, TokenType.Semicolon);

	e.members ~= member;
	return e;
}

ir.Enum parseEnum(TokenStream ts)
{
	auto e = new ir.Enum();
	e.location = ts.peek.location;

	auto mark = ts.save();
	try {
		// enum int a = 3;
		return tryParseManifestConstant(ts);
	} catch (CompilerError error) {
		if (error.neverIgnore) {
			throw error;
		}
		ts.restore(mark);
	}

	match(ts, TokenType.Enum);
	if (ts.peek.type == TokenType.Identifier) {
		auto nameTok = match(ts, TokenType.Identifier);
		e.name = nameTok.value;
	}

	if (matchIf(ts, TokenType.Assign)) {
		// enum a = 3;
		auto member = ir.Enum.Member();
		member.location = ts.peek.location;
		member.name = e.name;
		e.name.length = 0;
		member.init = parseAssignExp(ts);
		e.members ~= member;
		match(ts, TokenType.Semicolon);
	}

	if (matchIf(ts, TokenType.Colon)) {
		e.base = parseType(ts);
	}
	if (matchIf(ts, TokenType.OpenBrace)) {
		while (ts.peek.type != TokenType.CloseBrace) {
			e.members ~= parseEnumMember(ts);
			if (ts.peek.type != TokenType.CloseBrace) {
				match(ts, TokenType.Comma);
			}
		}
		match(ts, TokenType.CloseBrace);
	}

	return e;
}

ir.Enum.Member parseEnumMember(TokenStream ts)
{
	auto member = ir.Enum.Member();
	member.location = ts.peek.location;

	auto nameTok = match(ts, TokenType.Identifier);
	member.name = nameTok.value;
	if (matchIf(ts, TokenType.Assign)) {
		member.init = parseAssignExp(ts);
	}

	return member;
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
				throw new CompilerError(linkageTok.location, "expected 'C', 'C++', 'D', 'Windows', 'Pascal', 'System', or 'Volt', not '" ~
										linkageTok.value ~ "'.");
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
		auto nameTok = match(ts, TokenType.Identifier);
		if (nameTok.value != "disable") {
			throw new CompilerError(nameTok.location, "expected 'disable'.");
		}
		attr.kind = ir.Attribute.Kind.Disable;
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
	default:
		assert(false);
	}

	if (matchIf(ts, TokenType.OpenBrace)) {
		while (ts.peek.type != TokenType.CloseBrace) {
			attr.members ~= parseTopLevelDecl(ts, inModule);
		}
		match(ts, TokenType.CloseBrace);
	} else if (matchIf(ts, TokenType.Colon)) {
		// Colons are implictly converted into braces; the IR knows nothing of colons.
		while (ts.peek.type != TokenType.CloseBrace && ts.peek.type != TokenType.End) {
			attr.members ~= parseTopLevelDecl(ts, inModule);
		}
	} else {
		attr.members ~= parseTopLevelDecl(ts, inModule);
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
	sa.exp = parseAssignExp(ts);
	if (matchIf(ts, TokenType.Comma)) {
		sa.message = parseAssignExp(ts);
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
		if (ts.peek.type == TokenType.Unittest) {
			ts.get();
			condition.identifier = "unittest";
		} else {
			auto identTok = match(ts, TokenType.Identifier);
			condition.identifier = identTok.value;
		}
		match(ts, TokenType.CloseParen);
		break;
	case TokenType.Debug:
		condition.kind = ir.Condition.Kind.Debug;
		ts.get();
		if (matchIf(ts, TokenType.OpenParen)) {
			auto identTok = match(ts, TokenType.Identifier);
			condition.identifier = identTok.value;
			match(ts, TokenType.CloseParen);
		}
		break;
	case TokenType.Static:
		condition.kind = ir.Condition.Kind.StaticIf;
		ts.get();
		match(ts, TokenType.If);
		match(ts, TokenType.OpenParen);
		condition.exp = parseExp(ts);
		match(ts, TokenType.CloseParen);
		break;
	default:
		throw new CompilerError(ts.peek.location, "expected 'version', 'debug', or 'static', not '" ~ ts.peek.value ~ "'.");
	}

	return condition;
}

ir.ConditionTopLevel parseConditionTopLevel(TokenStream ts, bool inModule = false)
{
	auto ctl = new ir.ConditionTopLevel();
	ctl.location = ts.peek.location;

	ctl.condition = parseCondition(ts);
	if (matchIf(ts, TokenType.Colon)) {
		// Colons are implictly converted into braces; the IR knows nothing of colons.
		while (ts.peek.type != TokenType.CloseBrace && ts.peek.type != TokenType.End) {
			ctl.members ~= parseTopLevelDecl(ts, inModule);
		}
		return ctl;  // Else blocks aren't tied to colon conditionals.
	} else if (matchIf(ts, TokenType.OpenBrace)) {
		while (ts.peek.type != TokenType.CloseBrace) {
			ctl.members ~= parseTopLevelDecl(ts, inModule);
		}
		match(ts, TokenType.CloseBrace);
	} else {
		ctl.members ~= parseTopLevelDecl(ts, inModule);
	}

	if (matchIf(ts, TokenType.Else)) {
		ctl.elsePresent = true;
		if (matchIf(ts, TokenType.Colon)) {
			// Colons are implictly converted into braces; the IR knows nothing of colons.
			while (ts.peek.type != TokenType.CloseBrace && ts.peek.type != TokenType.End) {
				ctl.members ~= parseTopLevelDecl(ts, inModule);
			}
		} else if (matchIf(ts, TokenType.OpenBrace)) {
			while (ts.peek.type != TokenType.CloseBrace) {
				ctl._else ~= parseTopLevelDecl(ts);
			}
			match(ts, TokenType.CloseBrace);
		} else {
			ctl._else ~= parseTopLevelDecl(ts);
		}
	}

	return ctl;
}
