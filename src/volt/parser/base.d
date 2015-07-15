// Copyright © 2010-2011, Bernard Helyer.  All rights reserved.
// Copyright © 2010, Jakob Ovrum.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.base;

import watt.text.format : format;

import volt.errors;
import volt.exceptions;
import volt.token.token : Token, TokenType, tokenToString;
import volt.token.stream : TokenStream;
import volt.token.location : Location;
import volt.parser.errors : ParserError, ParserUnexpectedToken,
                            ParserParseFailed, ParserUnsupportedFeature,
                            ParserInvalidIntegerLiteral, ParserDocMultiple,
                            ParserStrayDocComment, ParserWrongToken,
                            ParserPanic, ParserAllArgumentsMustBeLabelled,
                            ParserExpected;


import ir = volt.ir.ir;


enum ParseStatus {
	Succeeded = 1,
	Failed = 0
}
alias Succeeded = ParseStatus.Succeeded;
alias Failed = ParseStatus.Failed;


/*
 *
 * Stream error rasing functions.
 *
 */

ParseStatus parsePanic(ParserStream ps, Location loc,
                       ir.NodeType nodeType, string message,
                       string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserPanic(loc, nodeType, message, file, line);
	ps.parserErrors ~= e;
	ps.neverIgnoreError = true;
	return Failed;
}

ParseStatus unexpectedToken(ParserStream ps, ir.NodeType ntype,
                            string file = __FILE__, const int line = __LINE__)
{
	string found = ps.peek.type.tokenToString;
	auto e = new ParserUnexpectedToken(ps.peek.location, ntype, found,
	                                   file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus unexpectedToken(ParserStream ps, ir.Node n,
                            string file = __FILE__, const int line = __LINE__)
{
	return unexpectedToken(ps, n.nodeType, file, line);
}

ParseStatus wrongToken(ParserStream ps, ir.NodeType ntype,
                       Token found, TokenType expected,
                       string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserWrongToken(found.location, ntype, found.type,
	                              expected, file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus parseFailed(ParserStream ps, ir.NodeType ntype,
                        string file = __FILE__, const int line = __LINE__)
{
	assert(ps.parserErrors.length >= 1);
	auto ntype2 = ps.parserErrors[$-1].nodeType;
	auto e = new ParserParseFailed(ps.peek.location, ntype, ntype2,
	                               file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus parseFailed(ParserStream ps, ir.Node n,
                        string file = __FILE__, const int line = __LINE__)
{
	return parseFailed(ps, n.nodeType, file, line);
}

ParseStatus parseFailed(ParserStream ps, ir.NodeType ntype, ir.NodeType ntype2,
                        string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserParseFailed(ps.peek.location, ntype, ntype2,
	                               file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus unsupportedFeature(ParserStream ps, ir.Node n, string s,
                               string file = __FILE__, const int l = __LINE__)
{
	auto e = new ParserUnsupportedFeature(n.location, n.nodeType, s, file, l);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus invalidIntegerLiteral(ParserStream ps, Location loc,
                                  string file = __FILE__,
                                  const int line = __LINE__)
{
	auto e = new ParserInvalidIntegerLiteral(loc, ir.NodeType.Constant,
	                                         file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus parseExpected(ParserStream ps, Location loc,
                          ir.NodeType nodeType, string message,
                          string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserExpected(loc, nodeType, message, file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus parseExpected(ParserStream ps, Location loc,
                          ir.Node n, string message,
                          string file = __FILE__, const int line = __LINE__)
{
	return parseExpected(ps, loc, n.nodeType, message, file, line);
}

ParseStatus allArgumentsMustBeLabelled(ParserStream ps, Location loc,
                                       string file = __FILE__,
                                       const int line = __LINE__)
{
	auto e = new ParserAllArgumentsMustBeLabelled(loc, file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus docCommentMultiple(ParserStream ps, Location loc,
                               string file = __FILE__,
                               const int line = __LINE__)
{
	auto e = new ParserDocMultiple(loc, file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus strayDocComment(ParserStream ps, Location loc,
                            string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserStrayDocComment(loc, file, line);
	ps.parserErrors ~= e;
	return Failed;
}


/*
 *
 * Stream checks helper functions.
 *
 */


/**
 * Match the current token on the parserstream @ps against @type.
 * Does not advance the parserstream.
 *
 * Side-effects:
 *     If token is not type raises a unexpected token error.
 */
ParseStatus checkToken(ParserStream ps, ir.NodeType ntype, TokenType type,
                       string file = __FILE__, const int line = __LINE__)
{
	if (ps == type) {
		return Succeeded;
	}

	return wrongToken(ps, ntype, ps.peek, type, file, line);
}

/**
 * Match the current token on the parserstream @ps against @type.
 * Does not advance the parserstream.
 *
 * Side-effects:
 *     If token is not type raises a unexpected token error.
 */
ParseStatus checkTokens(ParserStream ps, ir.NodeType ntype, TokenType[] types,
                        string file = __FILE__, const int line = __LINE__)
{
	size_t i;
	for (; i < types.length; i++) {
		if (ps.lookahead(i).type != types[i]) {
			break;
		}
	}

	// Did the counter reach the end, all tokens checked.
	if (types.length == i) {
		return Succeeded;
	}

	return wrongToken(ps, ntype, ps.lookahead(i), types[i], file, line);
}

/**
 * Match the current Token on the ParserStream @ps against @type.
 *
 * Side-effects:
 *     Advances the ParserStream if the current Token is of @type.
 *     If the Token is not @type an unexpected token error is raised.
 */
ParseStatus match(ParserStream ps, ir.NodeType ntype, TokenType type,
                  string file = __FILE__, const int line = __LINE__)
{
	if (ps == type) {
		ps.get();
		return Succeeded;
	}

	return wrongToken(ps, ntype, ps.peek, type, file, line);
}

/**
 * Match the current token on the parserstream @ps against @type.
 *
 * Side-effects:
 *     Advances the tokenstream if current token is of @type.
 *     If token is not type raises a unexpected token error.
 */
ParseStatus match(ParserStream ps, ir.Node node, TokenType type,
                  string file = __FILE__, const int line = __LINE__)
{
	if (ps == type) {
		ps.get();
		return Succeeded;
	}

	return wrongToken(ps, node.nodeType, ps.peek, type, file, line);
}

/**
 * Match the current tokens on the parserstream @ps against @types.
 *
 * Side-effects:
 *     Advances the tokenstream if all the tokens matches @types.
 *     If token is not type raises a unexpected token error.
 */
ParseStatus match(ParserStream ps, ir.NodeType ntype, TokenType[] types,
                  string file = __FILE__, const int line = __LINE__)
{
	size_t i;
	for (; i < types.length; i++) {
		if (ps.lookahead(i).type != types[i]) {
			break;
		}
	}

	// Did the counter reach the end, all tokens checked.
	if (types.length == i) {
		for (size_t k; k < i; k++) {
			ps.get();
		}
		return Succeeded;
	}

	return wrongToken(ps, ntype, ps.lookahead(i), types[i], file, line);
}

/**
 * Match the current token on the parserstream @ps against @type.
 *
 * Side-effects:
 *     Advances the tokenstream if current token is of @type.
 *     If token is not type raises a unexpected token error.
 */
ParseStatus match(ParserStream ps, ir.Node n, TokenType type, out Token tok,
                  string file = __FILE__, const int line = __LINE__)
{
	return match(ps, n.nodeType, type, tok, file, line);
}

/**
 * Match the current token on the parserstream @ps against @type.
 *
 * Side-effects:
 *     Advances the tokenstream if current token is of @type.
 *     If token is not type raises a unexpected token error.
 */
ParseStatus match(ParserStream ps, ir.NodeType nodeType, TokenType type, out Token tok,
                  string file = __FILE__, const int line = __LINE__)
{
	if (ps == type) {
		tok = ps.get();
		return Succeeded;
	}

	return wrongToken(ps, nodeType, ps.peek, type, file, line);
}

/**
 * Matches the current token on the parserstream @ps against @type
 * and if they matches gets it from the stream.
 *
 * Side-effects:
 *     None
 */
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
ParseStatus eatComments(ParserStream ps)
{
	while (ps.peek.type == TokenType.DocComment) {
		auto commentTok = ps.get();
		if (commentTok.isBackwardsComment) {
			if (ps.retroComment is null) {
				return strayDocComment(ps, commentTok.location);
			} else {
				*ps.retroComment = commentTok.value;
			}
		} else {
			ps.addComment(commentTok);
		}
	}
	return Succeeded;
}


/*
 *
 * Common parse functions.
 *
 */


/**
 * Parse a QualifiedName, leadingDot optinal.
 */
ParseStatus parseQualifiedName(ParserStream ps, out ir.QualifiedName name,
                               bool allowLeadingDot = false)
{
	name = new ir.QualifiedName();
	auto t = ps.peek;
	auto startLocation = t.location;

	// Consume any leading dots if allowed, if not allowed error.
	if (allowLeadingDot && t.type == TokenType.Dot) {
		t = ps.get();
		name.leadingDot = true;
	} else if (!allowLeadingDot && t.type == TokenType.Dot) {
		return unexpectedToken(ps, ir.NodeType.QualifiedName);
	}

	// Consume all identifier dot pairs.
	do {
		ir.Identifier ident;
		auto succeeded = parseIdentifier(ps, ident);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.QualifiedName);
		}
		name.identifiers ~= ident;

		if (ps == TokenType.Dot) {
			ps.get();
		} else {
			break;
		}
	} while(true);

	name.location = t.location - startLocation;

	return Succeeded;
}

/**
 * Parse a single Identifier.
 */
ParseStatus parseIdentifier(ParserStream ps, out ir.Identifier i)
{
	if (ps.peek.type != TokenType.Identifier) {
		return wrongToken(ps, ir.NodeType.Identifier,
		                  ps.peek, TokenType.Identifier);
	}
	auto t = ps.get();
	i = new ir.Identifier();

	i.value = t.value;
	i.location = t.location;

	return Succeeded;
}


/*
 *
 * Common class(es).
 *
 */


class ParserStream : TokenStream
{
public:
	ParserError[] parserErrors;
	CompilerException ce;

	/// Error raised shouldn't be ignored.
	bool neverIgnoreError;

public:
	this(Token[] tokens)
	{
		super(tokens);
	}

	void resetErrors()
	{
		parserErrors = [];
	}
}
