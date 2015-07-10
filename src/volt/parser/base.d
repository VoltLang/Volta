// Copyright © 2010-2011, Bernard Helyer.  All rights reserved.
// Copyright © 2010, Jakob Ovrum.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.base;

version(Volt) {
	import watt.text.format;
} else {
	import std.string : format;
}

import volt.errors;
import volt.token.token;
import volt.token.stream;

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
Token match(TokenStream ts, TokenType type, string file = __FILE__, size_t line = __LINE__)
{
	auto t = ts.peek;

	// Condition true is good path.
	if (t.type == type)
		return ts.get();

	throw makeExpected(t.location, type.tokenToString, t.value, file, line);
}

bool matchIf(TokenStream ts, TokenType type)
{
	if (ts.peek.type == type) {
		ts.get();
		return true;
	} else {
		return false;
	}
}

/**
 * Add all doccomment tokens to the current comment level.
 */
void eatComments(TokenStream ts)
{
	while (ts.peek.type == TokenType.DocComment) {
		auto commentTok = match(ts, TokenType.DocComment);
		if (commentTok.isBackwardsComment) {
			if (ts.retroComment is null) {
				throw makeStrayDocComment(commentTok.location);
			} else {
				*ts.retroComment = commentTok.value;
			}
		} else {
			ts.addComment(commentTok);
		}
	}
}

/**
 *
 */
ir.QualifiedName parseQualifiedName(TokenStream ts, bool allowLeadingDot = false)
{
	auto name = new ir.QualifiedName();
	auto t = ts.peek;
	auto startLocation = t.location;

	// Consume any leading dots if allowed, if not allowed
	// the below while loop match will cause an error.
	if (allowLeadingDot && t.type == TokenType.Dot) {
		t = match(ts, TokenType.Dot);
		name.leadingDot = true;
	}

	// Consume all identifier dot pairs.
	do {
		name.identifiers ~= parseIdentifier(ts);

		if (ts == TokenType.Dot) {
			t = match(ts, TokenType.Dot);
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
ir.Identifier parseIdentifier(TokenStream ts)
{
	auto t = match(ts, TokenType.Identifier);
	auto i = new ir.Identifier();

	i.value = t.value;
	i.location = t.location;

	return i;
}
