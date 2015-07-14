// Copyright © 2010-2011, Bernard Helyer.  All rights reserved.
// Copyright © 2010, Jakob Ovrum.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.base;

import watt.text.format : format;

import volt.errors;
import volt.token.token : Token, TokenType, tokenToString;
import volt.parser.stream : ParserStream;

import ir = volt.ir.ir;


/**
 * Match the current token on the tokenstream @ts against @type.
 *
 * Throws:
 *     CompilerError if the current token isn't of the @type type.
 *
 * Side-effects:
 *     Advances the tokenstream if current token is of @type.
 */
Token match(ParserStream ps, TokenType type, string file = __FILE__, size_t line = __LINE__)
{
	auto t = ps.peek;

	// Condition true is good path.
	if (t.type == type)
		return ps.get();

	throw makeExpected(t.location, type.tokenToString, t.value, file, line);
}

bool matchIf(ParserStream ps, TokenType type)
{
	if (ps.peek.type == type) {
		ps.get();
		return true;
	} else {
		return false;
	}
}

/**
 * Add all doccomment tokens to the current comment level.
 */
void eatComments(ParserStream ps)
{
	while (ps.peek.type == TokenType.DocComment) {
		auto commentTok = match(ps, TokenType.DocComment);
		if (commentTok.isBackwardsComment) {
			if (ps.retroComment is null) {
				throw makeStrayDocComment(commentTok.location);
			} else {
				*ps.retroComment = commentTok.value;
			}
		} else {
			ps.addComment(commentTok);
		}
	}
}

/**
 *
 */
ir.QualifiedName parseQualifiedName(ParserStream ps, bool allowLeadingDot = false)
{
	auto name = new ir.QualifiedName();
	auto t = ps.peek;
	auto startLocation = t.location;

	// Consume any leading dots if allowed, if not allowed
	// the below while loop match will cause an error.
	if (allowLeadingDot && t.type == TokenType.Dot) {
		t = match(ps, TokenType.Dot);
		name.leadingDot = true;
	}

	// Consume all identifier dot pairs.
	do {
		name.identifiers ~= parseIdentifier(ps);

		if (ps == TokenType.Dot) {
			t = match(ps, TokenType.Dot);
		} else {
			break;
		}
	} while(true);

	name.location = t.location - startLocation;

	return name;
}

/**
 *
 */
ir.Identifier parseIdentifier(ParserStream ps)
{
	auto t = match(ps, TokenType.Identifier);
	auto i = new ir.Identifier();

	i.value = t.value;
	i.location = t.location;

	return i;
}
