// Copyright © 2010-2011, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.token.lexer;

version(Volt) {
	import core.stdc.time : time, localtime;
	import watt.conv : toInt;
	import watt.text.ascii : isDigit, isAlpha, isWhite;
	import watt.text.format : format;
	import watt.text.utf : encode;
	import watt.text.string : indexOf;
} else {
	import std.uni : isWhite, isAlpha;
	import std.utf : toUTF8;
	import std.conv : to;
	import std.string : format, indexOf;
	import std.ascii : isDigit;
	import std.array : array;
	import std.algorithm : count;
	import std.c.time : time, localtime;
}

import volt.token.location : Location;
import volt.token.source : Source, Mark;
import volt.token.stream : Token, TokenType, TokenStream, identifierType;
import volt.token.writer : TokenWriter;
import volt.util.string : cleanComment;
import volt.errors;

/**
 * Tokenizes a string pretending to be at the given location.
 *
 * Throws:
 *   CompilerError on errors.
 *
 * Returns:
 *   A TokenStream filled with tokens.
 */
TokenStream lex(string src, Location loc)
{
	return lex(new Source(src, loc));
}

/**
 * Tokenizes a source file.
 *
 * Side-effects:
 *   Will advance the source location, on success this will be EOF.
 *
 * Throws:
 *   CompilerError on errors.
 *
 * Returns:
 *   A TokenStream filled with tokens.
 */
TokenStream lex(Source source)
{
	auto tw = new TokenWriter(source);

	do {
		if (lexNext(tw))
			continue;

		throw makeUnexpected(tw.source.location, format("%s", tw.source.current));
	} while (tw.lastAdded.type != TokenType.End);

	return tw.getStream();
}

private:

/**
 * Match and advance if matched.
 *
 * Side-effects:
 *   If @src.current and @c matches, advances source to next character.
 *
 * Throws:
 *   CompilerError if @src.current did not match @c.
 */
void match(Source src, dchar c)
{
	dchar cur = src.current;
	if (cur != c) {
		version(Volt) {
			throw makeExpected(src.location, encode(c), encode(cur));
		} else {
			throw makeExpected(src.location, to!string(c), to!string(cur));
		}
	}

	// Advance to the next character.
	src.next();
}

Token currentLocationToken(TokenWriter tw)
{
	auto t = new Token();
	t.location = tw.source.location;
	return t;
}

bool ishex(dchar c)
{
	return isDigit(c) || c >= 'A' && c <= 'F' || c >= 'a' && c <= 'f';
}

bool isoctal(dchar c)
{
	return c >= '0' && c <= '7';
}

enum Position { Start, MiddleOrEnd }

bool isdalpha(dchar c, Position position)
{
	if (position == Position.Start) {
		return isAlpha(c) || c == '_';
	} else {
		return isAlpha(c) || c == '_' || isDigit(c);
	}
}

bool lexNext(TokenWriter tw)
{
	TokenType type = nextLex(tw);

	switch (type) {
	case TokenType.End:
		return lexEOF(tw);
	case TokenType.Identifier:
		return lexIdentifier(tw);
	case TokenType.CharacterLiteral:
		return lexCharacter(tw);
	case TokenType.StringLiteral:
		return lexString(tw);
	case TokenType.Symbol:
		return lexSymbol(tw);
	case TokenType.Number:
		return lexNumber(tw);
	default:
		break;
	}

	return false;
}

/// Return which TokenType to try and lex next.
TokenType nextLex(TokenWriter tw)
{
	skipWhitespace(tw);
	if (tw.source.eof) {
		return TokenType.End;
	}

	if (isAlpha(tw.source.current) || tw.source.current == '_') {
		bool lookaheadEOF;
		if (tw.source.current == 'r' || tw.source.current == 'q' || tw.source.current == 'x') {
			dchar oneAhead = tw.source.lookahead(1, lookaheadEOF);
			if (oneAhead == '"') {
				return TokenType.StringLiteral;
			} else if (tw.source.current == 'q' && oneAhead == '{') {
				return TokenType.StringLiteral;
			}
		}
		return TokenType.Identifier;
	}

	if (tw.source.current == '\'') {
		return TokenType.CharacterLiteral;
	}

	if (tw.source.current == '"' || tw.source.current == '`') {
		return TokenType.StringLiteral;
	}

	if (isDigit(tw.source.current)) {
		return TokenType.Number;
	}

	return TokenType.Symbol;
}

void skipWhitespace(TokenWriter tw)
{
	while (isWhite(tw.source.current)) {
		tw.source.next();
		if (tw.source.eof) break;
	}
}

void addIfDocComment(TokenWriter tw, Token commentToken, string s, string docsignifier)
{
	auto closeIndex = s.indexOf("@}");
	if ((s.length <= 2 || s[0 .. 2] != docsignifier) && closeIndex < 0) {
		return;
	}
	commentToken.type = TokenType.DocComment;
	commentToken.value = closeIndex < 0 ? cleanComment(s, commentToken.isBackwardsComment) : "@}";
	tw.addToken(commentToken);
}

void skipLineComment(TokenWriter tw)
{
	auto commentToken = currentLocationToken(tw);
	auto mark = tw.source.save();

	match(tw.source, '/');
	while (tw.source.current != '\n') {
		tw.source.next();
		if (tw.source.eof) {
			return;
		}
	}

	addIfDocComment(tw, commentToken, tw.source.sliceFrom(mark), "//");
}

void skipBlockComment(TokenWriter tw)
{
	auto commentToken = currentLocationToken(tw);
	auto mark = tw.source.save();

	bool looping = true;
	while (looping) {
		if (tw.source.eof) {
			throw makeExpected(tw.source.location, "end of block comment");
		}
		if (tw.source.current == '/') {
			match(tw.source, '/');
			if (tw.source.current == '*') {
				warning(tw.source.location, "'/*' inside of block comment.");
			}
		} else if (tw.source.current == '*') {
			match(tw.source, '*');
			if (tw.source.current == '/') {
				match(tw.source, '/');
				looping = false;
			}
		} else {
			tw.source.next();
		}
	}

	addIfDocComment(tw, commentToken, tw.source.sliceFrom(mark), "**");
}

void skipNestingComment(TokenWriter tw)
{
	auto commentToken = currentLocationToken(tw);
	auto mark = tw.source.save();

	int depth = 1;
	while (depth > 0) {
		if (tw.source.eof) {
			throw makeExpected(tw.source.location, "end of nested comment");
		}
		if (tw.source.current == '+') {
			match(tw.source, '+');
			if (tw.source.current == '/') {
				match(tw.source, '/');
				depth--;
			}
		} else if (tw.source.current == '/') {
			match(tw.source, '/');
			if (tw.source.current == '+') {
				depth++;
			}
		} else {
			tw.source.next();
		}
	}

	addIfDocComment(tw, commentToken, tw.source.sliceFrom(mark), "++");
}

bool lexEOF(TokenWriter tw)
{
	if (!tw.source.eof) {
		return false;
	}

	auto eof = currentLocationToken(tw);
	eof.type = TokenType.End;
	eof.value = "EOF";
	tw.addToken(eof);
	return true;
}

// This is a bit of a dog's breakfast.
bool lexIdentifier(TokenWriter tw)
{
	assert(isAlpha(tw.source.current) || tw.source.current == '_' || tw.source.current == '@');

	auto identToken = currentLocationToken(tw);
	Mark m = tw.source.save();
	tw.source.next();

	while (isAlpha(tw.source.current) || isDigit(tw.source.current) || tw.source.current == '_') {
		tw.source.next();
		if (tw.source.eof) break;
	}

	identToken.value = tw.source.sliceFrom(m);
	if (identToken.value.length == 0) {
		throw panic(identToken.location, "empty identifier string.");
	}
	if (identToken.value[0] == '@') {
		auto i = identifierType(identToken.value);
		if (i == TokenType.Identifier) {
			throw makeExpected(identToken.location, "@attribute");
		}
	}


	bool retval = lexSpecialToken(tw, identToken);
	if (retval) return true;
	identToken.type = identifierType(identToken.value);
	tw.addToken(identToken);

	return true;
}

bool lexSpecialToken(TokenWriter tw, Token token)
{
	const string[12] months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
	const string[7] days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

	switch(token.value) {
	case "__DATE__":
		auto thetime = time(null);
		auto tm = localtime(&thetime);
		token.type = TokenType.StringLiteral;
		token.value = format(`"%s %02s %s"`,
		                     months[tm.tm_mon],
		                     tm.tm_mday,
		                     1900 + tm.tm_year);
		tw.addToken(token);
		return true;

	case "__EOF__":
		tw.source.eof = true;
		return true;

	case "__TIME__":
		auto thetime = time(null);
		auto tm = localtime(&thetime);
		token.type = TokenType.StringLiteral;
		token.value = format(`"%02s:%02s:%02s"`, tm.tm_hour, tm.tm_min,
		                     tm.tm_sec);
		tw.addToken(token);
		return true;

	case "__TIMESTAMP__":
		auto thetime = time(null);
		auto tm = localtime(&thetime);
		token.type = TokenType.StringLiteral;
		token.value = format(`"%s %s %02s %02s:%02s:%02s %s"`,
		                     days[tm.tm_wday], months[tm.tm_mon],
		                     tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec,
		                     1900 + tm.tm_year);
		tw.addToken(token);
		return true;

	case "__VENDOR__":
		token.type = TokenType.StringLiteral;
		token.value = "N/A";
		tw.addToken(token);
		return true;
	case "__VERSION__":
		token.type = TokenType.IntegerLiteral;
		token.value = "N/A";
		tw.addToken(token);
		return true;
	default:
		return false;
	}
}

bool lexSymbol(TokenWriter tw)
{
	switch (tw.source.current) {
	case '/':
		return lexSlash(tw);
	case '.':
		return lexDot(tw);
	case '&':
		return lexSymbolOrSymbolAssignOrDoubleSymbol(tw, '&',
			TokenType.Ampersand, TokenType.AmpersandAssign, TokenType.DoubleAmpersand);
	case '|':
		return lexSymbolOrSymbolAssignOrDoubleSymbol(tw, '|',
			TokenType.Pipe, TokenType.PipeAssign, TokenType.DoublePipe);
	case '-':
		return lexSymbolOrSymbolAssignOrDoubleSymbol(tw, '-',
			TokenType.Dash, TokenType.DashAssign, TokenType.DoubleDash);
	case '+':
		return lexSymbolOrSymbolAssignOrDoubleSymbol(tw, '+',
			TokenType.Plus, TokenType.PlusAssign, TokenType.DoublePlus);
	case '<':
		return lexLess(tw);
	case '>':
		return lexGreater(tw);
	case '!':
		return lexBang(tw);
	case '(':
		return lexOpenParen(tw);
	case ')':
		return lexSingleSymbol(tw, ')', TokenType.CloseParen);
	case '[':
		return lexSingleSymbol(tw, '[', TokenType.OpenBracket);
	case ']':
		return lexSingleSymbol(tw, ']', TokenType.CloseBracket);
	case '{':
		return lexSingleSymbol(tw, '{', TokenType.OpenBrace);
	case '}':
		return lexSingleSymbol(tw, '}', TokenType.CloseBrace);
	case '?':
		return lexSingleSymbol(tw, '?', TokenType.QuestionMark);
	case ',':
		return lexSingleSymbol(tw, ',', TokenType.Comma);
	case ';':
		return lexSingleSymbol(tw, ';', TokenType.Semicolon);
	case ':':
		return lexSingleSymbol(tw, ':', TokenType.Colon);
	case '$':
		return lexSingleSymbol(tw, '$', TokenType.Dollar);
	case '@':
		return lexSingleSymbol(tw, '@', TokenType.At);
	case '=':
		return lexSymbolOrSymbolAssign(tw, '=', TokenType.Assign, TokenType.DoubleAssign);
	case '*':
		return lexSymbolOrSymbolAssign(tw, '*', TokenType.Asterix, TokenType.AsterixAssign);
	case '%':
		return lexSymbolOrSymbolAssign(tw, '%', TokenType.Percent, TokenType.PercentAssign);
	case '^':
		return lexCaret(tw);
	case '~':
		return lexSymbolOrSymbolAssign(tw, '~', TokenType.Tilde, TokenType.TildeAssign);
	case '#':
		return lexPragma(tw);
	default:
		break;
	}
	return false;
}

bool lexCaret(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	token.type = TokenType.Caret;
	match(tw.source, '^');

	if (tw.source.current == '=') {
		match(tw.source, '=');
		token.type = TokenType.CaretAssign;
	} else if (tw.source.current == '^') {
		match(tw.source, '^');
		if (tw.source.current == '=') {
			match(tw.source, '=');
			token.type = TokenType.DoubleCaretAssign;
		} else {
			token.type = TokenType.DoubleCaret;
		}
	}

	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return true;
}

bool lexSlash(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	auto type = TokenType.Slash;
	match(tw.source, '/');

	switch (tw.source.current) {
	case '=':
		match(tw.source, '=');
		type = TokenType.SlashAssign;
		break;
	case '/':
		skipLineComment(tw);
		return true;
	case '*':
		skipBlockComment(tw);
		return true;
	case '+':
		skipNestingComment(tw);
		return true;
	default:
		break;
	}

	token.type = type;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);

	return true;
}

bool lexDot(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	auto type = TokenType.Dot;
	match(tw.source, '.');

	switch (tw.source.current) {
	case '.':
		match(tw.source, '.');
		if (tw.source.current == '.') {
			match(tw.source, '.');
			type = TokenType.TripleDot;
		} else {
			type = TokenType.DoubleDot;
		}
		break;
	default:
		break;
	}

	token.type = type;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);

	return true;
}

bool lexSymbolOrSymbolAssignOrDoubleSymbol(TokenWriter tw, dchar c, TokenType symbol, TokenType symbolAssign, TokenType doubleSymbol)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	auto type = symbol;
	match(tw.source, c);

	if (tw.source.current == '=') {
		match(tw.source, '=');
		type = symbolAssign;
	} else if (tw.source.current == c) {
		match(tw.source, c);
		type = doubleSymbol;
	}

	token.type = type;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);

	return true;
}

bool lexSingleSymbol(TokenWriter tw, dchar c, TokenType symbol)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	match(tw.source, c);
	token.type = symbol;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return true;
}

bool lexSymbolOrSymbolAssign(TokenWriter tw, dchar c, TokenType symbol, TokenType symbolAssign)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	auto type = symbol;
	match(tw.source, c);

	if (tw.source.current == '=') {
		match(tw.source, '=');
		type = symbolAssign;
	}

	token.type = type;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);

	return true;
}

bool lexOpenParen(TokenWriter tw)
{
	Mark m = tw.source.save();
	auto token = currentLocationToken(tw);
	match(tw.source, '(');
	token.type = TokenType.OpenParen;
	token.value = tw.source.sliceFrom(m);
	tw.addToken(token);

	return true;
}

bool lexLess(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	token.type = TokenType.Less;
	match(tw.source, '<');

	if (tw.source.current == '=') {
		match(tw.source, '=');
		token.type = TokenType.LessAssign;
	} else if (tw.source.current == '<') {
		match(tw.source, '<');
		if (tw.source.current == '=') {
			match(tw.source, '=');
			token.type = TokenType.DoubleLessAssign;
		} else {
			token.type = TokenType.DoubleLess;
		}
	} else if (tw.source.current == '>') {
		match(tw.source, '>');
		if (tw.source.current == '=') {
			match(tw.source, '=');
			token.type = TokenType.LessGreaterAssign;
		} else {
			token.type = TokenType.LessGreater;
		}
	}

	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return true;
}

bool lexGreater(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	token.type = TokenType.Greater;
	match(tw.source, '>');

	if (tw.source.current == '=') {
		match(tw.source, '=');
		token.type = TokenType.GreaterAssign;
	} else if (tw.source.current == '>') {
		match(tw.source, '>');
		if (tw.source.current == '=') {
			match(tw.source, '=');
			token.type = TokenType.DoubleGreaterAssign;
		} else if (tw.source.current == '>') {
			match(tw.source, '>');
			if (tw.source.current == '=') {
				match(tw.source, '=');
				token.type = TokenType.TripleGreaterAssign;
			} else {
				token.type = TokenType.TripleGreater;
			}
		} else {
			token.type = TokenType.DoubleGreater;
		}
	}

	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return true;
}

bool lexBang(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	token.type = TokenType.Bang;
	match(tw.source, '!');

	if (tw.source.current == '=') {
		match(tw.source, '=');
		token.type = TokenType.BangAssign;
	} else if (tw.source.current == '>') {
		match(tw.source, '>');
		if (tw.source.current == '=') {
			token.type = TokenType.BangGreaterAssign;
		} else {
			token.type = TokenType.BangGreater;
		}
	} else if (tw.source.current == '<') {
		match(tw.source, '<');
		if (tw.source.current == '>') {
			match(tw.source, '>');
			if (tw.source.current == '=') {
				match(tw.source, '=');
				token.type = TokenType.BangLessGreaterAssign;
			} else {
				token.type = TokenType.BangLessGreater;
			}
		} else if (tw.source.current == '=') {
			match(tw.source, '=');
			token.type = TokenType.BangLessAssign;
		} else {
			token.type = TokenType.BangLess;
		}
	}

	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return true;
}

// Escape sequences are not expanded inside of the lexer.

bool lexCharacter(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	match(tw.source, '\'');
	while (tw.source.current != '\'') {
		if (tw.source.eof) {
			throw makeExpected(token.location, "`'`");
		}
		if (tw.source.current == '\\') {
			match(tw.source, '\\');
			tw.source.next();
		} else {
			tw.source.next();
		}
	}
	match(tw.source, '\'');

	token.type = TokenType.CharacterLiteral;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return true;
}

bool lexString(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	dchar terminator;
	bool raw;
	bool postfix = true;

	if (tw.source.current == 'r') {
		match(tw.source, 'r');
		raw = true;
		terminator = '"';
	} else if (tw.source.current == 'q') {
		return lexQString(tw);
	} else if (tw.source.current == 'x') {
		match(tw.source, 'x');
		raw = false;
		terminator = '"';
	} else if (tw.source.current == '`') {
		raw = true;
		terminator = '`';
	} else if (tw.source.current == '"') {
		raw = false;
		terminator = '"';
	} else {
		return false;
	}

	match(tw.source, terminator);
	while (tw.source.current != terminator) {
		if (tw.source.eof) {
			throw makeExpected(token.location, "string literal terminator.");
		}
		if (!raw && tw.source.current == '\\') {
			match(tw.source, '\\');
			tw.source.next();
		} else {
			tw.source.next();
		}
	}
	match(tw.source, terminator);
	dchar postfixc = tw.source.current;
	if ((postfixc == 'c' || postfixc == 'w' || postfixc == 'd') && postfix) {
		match(tw.source, postfixc);
	}

	token.type = TokenType.StringLiteral;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);

	return true;
}

bool lexQString(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	token.type = TokenType.StringLiteral;
	auto mark = tw.source.save();
	bool leof;
	if (tw.source.lookahead(1, leof) == '{') {
		return lexTokenString(tw);
	}
	match(tw.source, 'q');
	match(tw.source, '"');

	dchar opendelimiter, closedelimiter;
	bool nesting = true;
	string identdelim = null;
	switch (tw.source.current) {
	case '[':
		opendelimiter = '[';
		closedelimiter = ']';
		break;
	case '(':
		opendelimiter = '(';
		closedelimiter = ')';
		break;
	case '<':
		opendelimiter = '<';
		closedelimiter = '>';
		break;
	case '{':
		opendelimiter = '{';
		closedelimiter = '}';
		break;
	default:
		nesting = false;
		if (isdalpha(tw.source.current, Position.Start)) {
			char[] buf;
			version(Volt) {
				buf ~= encode(tw.source.current);
			} else {
				buf ~= to!string(tw.source.current);
			}
			tw.source.next();
			while (isdalpha(tw.source.current, Position.MiddleOrEnd)) {
				version(Volt) {
					buf ~= encode(tw.source.current);
				} else {
					buf ~= to!string(tw.source.current);
				}
				tw.source.next();
			}
			match(tw.source, '\n');
			version(Volt) {
				identdelim = cast(string)new buf[0 .. $];
			} else {
				identdelim = buf.idup;
			}
		} else {
			opendelimiter = tw.source.current;
			closedelimiter = tw.source.current;
		}
	}

	if (identdelim is null) match(tw.source, opendelimiter);
	int nest = 1;
	while (true) {
		if (tw.source.eof) {
			throw makeExpected(token.location, "string literal terminator.");
		}
		if (tw.source.current == opendelimiter) {
			match(tw.source, opendelimiter);
			nest++;
		} else if (tw.source.current == closedelimiter) {
			match(tw.source, closedelimiter);
			nest--;
			if (nest == 0) {
				match(tw.source, '"');
			}
		} else {
			tw.source.next();
		}

		// Time to quit?
		if (nesting && nest <= 0) {
			break;
		} else if (identdelim !is null && tw.source.current == '\n') {
			size_t look = 1;
			bool restart;
			while (look - 1 < identdelim.length) {
				dchar c = tw.source.lookahead(look, leof);
				if (leof) {
					throw makeExpected(token.location, "string literal terminator.");
				}
				if (c != identdelim[look - 1]) {
					restart = true;
					break;
				}
				look++;
			}
			if (restart) {
				continue;
			}
			for (int i; 0 < look; i++) {
				tw.source.next();
			}
			match(tw.source, '"');
			break;
		} else if (tw.source.current == closedelimiter) {
			match(tw.source, closedelimiter);
			match(tw.source, '"');
			break;
		}
	}

	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return true;
}

bool lexTokenString(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	token.type = TokenType.StringLiteral;
	auto mark = tw.source.save();
	match(tw.source, 'q');
	match(tw.source, '{');
	auto dummystream = new TokenWriter(tw.source);

	int nest = 1;
	while (nest > 0) {
		bool retval = lexNext(dummystream);
		if (!retval) {
			throw makeExpected(dummystream.source.location, "token");
		}
		switch (dummystream.lastAdded.type) {
		case TokenType.OpenBrace:
			nest++;
			break;
		case TokenType.CloseBrace:
			nest--;
			break;
		case TokenType.End:
			throw makeExpected(dummystream.source.location, "end of token string literal");
		default:
			break;
		}
	}

	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return true;
}

/**
 * Consume characters from the source from the characters array until you can't.
 * Returns: the number of characters consumed, not counting underscores.
 */
size_t consume(Source src, const(dchar)[] characters...)
{
	size_t consumed;
	static bool isIn(const(dchar)[] chars, dchar arg) {
		foreach(c; chars) {
			if (c == arg)
				return true;
		}
		return false;
	}
	while (isIn(characters, src.current)) {
		if (src.current != '_') consumed++;
		src.next();
	}
	return consumed;
}

/**
 * Returns a string that is s, with all '_' removed.
 *    "134_hello" => "134hello"
 *    "_" => ""
 */
string removeUnderscores(string s)
{
	auto output = new char[](s.length);
	size_t i;
	foreach (c; s) {
		if (c == '_') {
			continue;
		}
		output[i++] = c;
	}
	version(Volt) {
		return i == s.length ? s : cast(string)new output[0 .. i];
	} else {
		return i == s.length ? s : output[0 .. i].idup;
	}
}

/**
 * Lex an integer literal and add the resulting token to tw.
 * If it detects the number is floating point, it will call lexReal directly.
 */
bool lexNumber(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto src = new Source(tw.source);
	auto mark = src.save();
	bool tmp;

	if (src.current == '0') {
		src.next();
		if (src.current == 'b' || src.current == 'B') {
			// Binary literal.
			src.next();
			auto consumed = consume(src, '0', '1', '_');
			if (consumed == 0) {
				throw makeExpected(src.location, "binary digit");
			}
		} else if (src.current == 'x' || src.current == 'X') {
			// Hexadecimal literal.
			src.next();
			if (src.current == '.' || src.current == 'p' || src.current == 'P') return lexReal(tw);
			auto consumed = consume(src, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
			                             'a', 'b', 'c', 'd', 'e', 'f',
			                             'A', 'B', 'C', 'D', 'E', 'F', '_');
			if ((src.current == '.' && src.lookahead(1, tmp) != '.') || src.current == 'p' || src.current == 'P') return lexReal(tw);
			if (consumed == 0) {
				throw makeExpected(src.location, "hexadecimal digit");
			}
		} else if (src.current == '1' || src.current == '2' || src.current == '3' || src.current == '4' || src.current == '5' ||
				src.current == '6' || src.current == '7') {
			/* This used to be an octal literal, which are gone.
			 * DMD treats this as an error, so we do too.
			 */
			throw makeUnsupported(src.location, "octal literals");
		} else if (src.current == 'f' || src.current == 'F' || (src.current == '.' && src.lookahead(1, tmp) != '.')) {
			return lexReal(tw);
		}
	} else if (src.current == '1' || src.current == '2' || src.current == '3' || src.current == '4' || src.current == '5' ||
	           src.current == '6' || src.current == '7' || src.current == '8' || src.current == '9') {
		src.next();
		if (src.current == '.' && src.lookahead(1, tmp) != '.') return lexReal(tw);
		consume(src, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_');
		if (src.current == '.' && src.lookahead(1, tmp) != '.') return lexReal(tw);
	} else {
		throw makeExpected(src.location, "integer literal");
	}

	if (src.current == 'f' || src.current == 'F' || src.current == 'e' || src.current == 'E') {
		return lexReal(tw);
	}

	tw.source.sync(src);
	if (tw.source.current == 'U' || tw.source.current == 'u') {
		tw.source.next();
		if (tw.source.current == 'L') tw.source.next();
	} else if (tw.source.current == 'L') {
		tw.source.next();
		if (tw.source.current == 'U' || tw.source.current == 'u') {
			tw.source.next();
		}
	}

	token.type = TokenType.IntegerLiteral;
	token.value = tw.source.sliceFrom(mark);
	token.value = removeUnderscores(token.value);
	tw.addToken(token);

	return true;
}

/// Lex a floating literal and add the resulting token to tw.
bool lexReal(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	bool skipRealPrologue;

	bool stop()
	{
		token.type = TokenType.FloatLiteral;
		token.value = tw.source.sliceFrom(mark);
		token.value = removeUnderscores(token.value);
		tw.addToken(token);
		return true;
	}

	if (tw.source.current == '.') {
		// .n
		tw.source.next();
		if (!isDigit(tw.source.current)) {
			throw makeExpected(tw.source.location, "digit after decimal point");
		}
		tw.source.next();
		consume(tw.source, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_');
		if (tw.source.current == 'L' || tw.source.current == 'f' || tw.source.current == 'F') {
			tw.source.next();
			return stop();
		}
	} else if (tw.source.current == '0') {
		tw.source.next();
		if (tw.source.current == 'x' || tw.source.current == 'X') {
			// 0xnP+
			tw.source.next();
			auto consumed = consume(tw.source, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
			                                   'a', 'b', 'c', 'd', 'e', 'f',
			                                   'A', 'B', 'C', 'D', 'E', 'F', '_');
			if (consumed == 0) {
				throw makeExpected(tw.source.location, "hexadecimal digit");
			}
			if (tw.source.current == 'p' || tw.source.current == 'P') {
				tw.source.next();
				if (tw.source.current == '+' || tw.source.current == '-') {
					tw.source.next();
				}
				skipRealPrologue = true;
			} else {
				throw makeExpected(tw.source.location, "exponent");
			}
		} else {
			// 0.n
			bool skipDecimalPrologue = false;
			if (tw.source.current == '.') skipDecimalPrologue = true; 
			if (skipDecimalPrologue || (tw.source.current != '0' && (isDigit(tw.source.current) || tw.source.current == '_'))) {
				if (!skipDecimalPrologue) {
					tw.source.next();
					consume(tw.source, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_');
				}
				match(tw.source, '.');
				consume(tw.source, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_');
				if (tw.source.current == 'L' || tw.source.current == 'f' || tw.source.current == 'F') {
					tw.source.next();
					return stop();
				}
			} else {
				throw makeExpected(tw.source.location, "non-zero digit, '_', or decimal point");
			}
		}
	} else if (isDigit(tw.source.current)) {
		// n.n
		consume(tw.source, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_');
		match(tw.source, '.');
		consume(tw.source, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_');
		if (tw.source.current == 'L' || tw.source.current == 'f' || tw.source.current == 'F') {
			tw.source.next();
			return stop();
		}
	} else {
		throw makeExpected(tw.source.location, "floating point literal");
	}

	if (tw.source.current == 'e' || tw.source.current == 'E' || skipRealPrologue) {
		if (!skipRealPrologue) {
			tw.source.next();
			if (tw.source.current == '+' || tw.source.current == '-') {
				tw.source.next();
			}
		}
		if (!isDigit(tw.source.current)) {
			throw makeExpected(tw.source.location, "digit");
		}
		consume(tw.source, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_');
		if (tw.source.current == 'L' || tw.source.current == 'f' || tw.source.current == 'F') {
			tw.source.next();
		}
	}

	return stop();
}

bool lexPragma(TokenWriter tw)
{
	match(tw.source, '#');
	skipWhitespace(tw);
	match(tw.source, 'l');
	match(tw.source, 'i');
	match(tw.source, 'n');
	match(tw.source, 'e');
	skipWhitespace(tw);

	lexNumber(tw);
	Token Int = tw.lastAdded;
	if (Int.type != TokenType.IntegerLiteral) {
		throw makeExpected(Int.location, "integer literal");
	}
	version(Volt) {
		int lineNumber = toInt(Int.value);
	} else {
		int lineNumber = to!int(Int.value);
	}
	tw.pop();

	skipWhitespace(tw);

	// Why yes, these do use a magical kind of string literal. Thanks for noticing! >_<
	match(tw.source, '"');
	dchar[] buf;
	while (tw.source.current != '"') {
		buf ~= tw.source.next();
	}
	match(tw.source, '"');
	version(Volt) {
		string filename = encode(buf);
	} else {
		string filename = toUTF8(buf);
	}

	assert(lineNumber >= 0);
	if (lineNumber == 0) {
		throw makeExpected(tw.source.location, "line number greater than zero");
	}
	tw.changeCurrentLocation(filename, cast(size_t)lineNumber);

	skipWhitespace(tw);

	return true;
}
