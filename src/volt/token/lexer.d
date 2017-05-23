// Copyright © 2010-2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.token.lexer;

import core.c.time : time, localtime;

import watt.text.ascii : isDigit, isAlpha, isWhite;
import watt.text.format : format;
import watt.text.string : indexOf;
import watt.conv : toInt;
import watt.text.utf : encode;

import volt.errors;
import volt.util.string : cleanComment;
import volt.token.location : Location;
import volt.token.source : Source, Mark;
import volt.token.token : Token, TokenType, identifierType;
import volt.token.writer : TokenWriter;
import volt.token.error;


/**
 * Tokenizes a source file.
 *
 * Side-effects:
 *   Will advance the source loc, on success this will be EOF.
 *
 * Throws:
 *   CompilerError on errors.
 *
 * Returns:
 *   A ParserStream filled with tokens.
 */
Token[] lex(Source source)
{
	auto tw = new TokenWriter(source);

	do {
		if (lexNext(tw))
			continue;

		assert(tw.errors.length > 0);
		foreach (err; tw.errors) {
			auto lpe = cast(LexerPanicError) err;
			if (lpe !is null) {
				throw lpe.panicException;
			}
		}
		throw makeError(tw.errors[0].loc, tw.errors[0].errorMessage());
	} while (tw.lastAdded.type != TokenType.End);

	return tw.getTokens();
}

private:

/**
 * Advance and return true if matched. Adds an error and returns false otherwise.
 *
 * Side-effects:
 *   If @src.current and @c matches, advances source to next character.
 */
bool match(TokenWriter tw, dchar c)
{
	dchar cur = tw.source.current;
	if (cur != c) {
		tw.errors ~= new LexerStringError(LexerError.Kind.Expected, tw.source.loc, cur, encode(c));
		return false;
	}

	// Advance to the next character.
	tw.source.next();
	return true;
}

/**
 * Call match for every character in a given string.
 * Returns false if any match fails, true otherwise.
 *
 * Side-effects:
 *   Same as calling match repeatedly.
 */
bool match(TokenWriter tw, string s)
{
	foreach (dchar c; s) {
		if (!match(tw, c)) {
			return false;
		}
	}
	return true;
}

/// Returns true if something has been matched, false otherwise. No errors generated.
bool matchIf(TokenWriter tw, dchar c)
{
	if (tw.source.current == c) {
		tw.source.next();
		return true;
	} else {
		return false;
	}
}

/**
 * Add a LexFailed error with the given string.
 */
LexStatus lexFailed(TokenWriter tw, string s)
{
	tw.errors ~= new LexerStringError(LexerError.Kind.LexFailed,
	                                  tw.source.loc, tw.source.current, s);
	return Failed;
}

/**
 * Add an Expected error with the given string.
 */
LexStatus lexExpected(TokenWriter tw, Location loc, string s)
{
	tw.errors ~= new LexerStringError(LexerError.Kind.Expected,
	                                  loc, tw.source.current, s);
	return Failed;
}

/**
 * Calls lexExpected with tw.source.loc.
 */
LexStatus lexExpected(TokenWriter tw, string s)
{
	return lexExpected(tw, tw.source.loc, s);
}

LexStatus lexUnsupported(TokenWriter tw, Location loc, string s)
{
	tw.errors ~= new LexerStringError(LexerError.Kind.Unsupported, loc, tw.source.current, s);
	return Failed;
}

LexStatus lexUnsupported(TokenWriter tw, string s)
{
	return lexUnsupported(tw, tw.source.loc, s);
}

LexStatus lexPanic(TokenWriter tw, Location loc, string msg)
{
	tw.errors ~= new LexerPanicError(loc, tw.source.current, panic(loc, msg));
	return Failed;
}

Token currentLocationToken(TokenWriter tw)
{
	Token t;
	t.loc = tw.source.loc;
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

LexStatus lexNext(TokenWriter tw)
{
	auto type = nextLex(tw);

	final switch (type) with (NextLex) {
	case Identifier:
		return lexIdentifier(tw);
	case CharacterLiteral:
		return lexCharacter(tw);
	case StringLiteral:
		return lexString(tw);
	case Symbol:
		return lexSymbol(tw);
	case Number:
		return lexNumber(tw);
	case End:
		return lexEOF(tw);
	}
}

enum NextLex
{
	Identifier,
	CharacterLiteral,
	StringLiteral,
	Symbol,
	Number,
	End,
}

/// Return which TokenType to try and lex next.
NextLex nextLex(TokenWriter tw)
{
	tw.source.skipWhitespace();

	if (tw.source.eof) {
		return NextLex.End;
	}

	if (isAlpha(tw.source.current) || tw.source.current == '_') {
		bool lookaheadEOF;
		if (tw.source.current == 'r' || tw.source.current == 'q' || tw.source.current == 'x') {
			dchar oneAhead = tw.source.lookahead(1, lookaheadEOF);
			if (oneAhead == '"') {
				return NextLex.StringLiteral;
			} else if (tw.source.current == 'q' && oneAhead == '{') {
				return NextLex.StringLiteral;
			}
		}
		return NextLex.Identifier;
	}

	if (tw.source.current == '\'') {
		return NextLex.CharacterLiteral;
	}

	if (tw.source.current == '"' || tw.source.current == '`') {
		return NextLex.StringLiteral;
	}

	if (isDigit(tw.source.current)) {
		return NextLex.Number;
	}

	return NextLex.Symbol;
}

void addIfDocComment(TokenWriter tw, Token commentToken, string s, string docsignifier)
{
	auto closeIndex = s.indexOf("@}");
	if ((s.length <= 2 || s[0 .. 2] != docsignifier) && closeIndex < 0) {
		return;
	}
	commentToken.type = TokenType.DocComment;
	cleanComment(s, commentToken.isBackwardsComment);
	commentToken.value = closeIndex < 0 ? s : "@}";
	tw.addToken(commentToken);
}

LexStatus skipLineComment(TokenWriter tw)
{
	auto commentToken = currentLocationToken(tw);
	auto mark = tw.source.save();

	if (!match(tw, '/')) {
		return lexPanic(tw, tw.source.loc, "expected '/'");
	}
	tw.source.skipEndOfLine();

	addIfDocComment(tw, commentToken, tw.source.sliceFrom(mark), "//");
	return Succeeded;
}

LexStatus skipBlockComment(TokenWriter tw)
{
	auto commentToken = currentLocationToken(tw);
	auto mark = tw.source.save();

	bool looping = true;
	while (looping) {
		if (tw.source.eof) {
			return lexExpected(tw, "end of block comment");
		}
		if (matchIf(tw, '/')) {
			if (tw.source.current == '*') {
				warning(tw.source.loc, "'/*' inside of block comment.");
			}
		} else if (matchIf(tw, '*')) {
			if (matchIf(tw, '/')) {
				looping = false;
			}
		} else {
			tw.source.next();
		}
	}

	addIfDocComment(tw, commentToken, tw.source.sliceFrom(mark), "**");
	return Succeeded;
}

LexStatus skipNestingComment(TokenWriter tw)
{
	auto commentToken = currentLocationToken(tw);
	auto mark = tw.source.save();

	int depth = 1;
	while (depth > 0) {
		if (tw.source.eof) {
			return lexExpected(tw, "end of nested comment");
		}
		if (matchIf(tw, '+')) {
			if (matchIf(tw, '/')) {
				depth--;
			}
		} else if (matchIf(tw, '/')) {
			if (tw.source.current == '+') {
				depth++;
			}
		} else {
			tw.source.next();
		}
	}

	addIfDocComment(tw, commentToken, tw.source.sliceFrom(mark), "++");
	return Succeeded;
}

LexStatus lexEOF(TokenWriter tw)
{
	if (!tw.source.eof) {
		return lexFailed(tw, "eof");
	}

	auto eof = currentLocationToken(tw);
	eof.type = TokenType.End;
	eof.value = "EOF";
	tw.addToken(eof);
	return Succeeded;
}

// This is a bit of a dog's breakfast.
LexStatus lexIdentifier(TokenWriter tw)
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
		return lexPanic(tw, identToken.loc, "empty identifier string.");
	}
	if (identToken.value[0] == '@') {
		auto i = identifierType(identToken.value);
		if (i == TokenType.Identifier) {
			return lexExpected(tw, identToken.loc, "@attribute");
		}
	}

	auto succeeded = lexSpecialToken(tw, identToken);
	if (succeeded) {
		return Succeeded;
	}
	tw.errors = [];
	identToken.type = identifierType(identToken.value);
	tw.addToken(identToken);

	return Succeeded;
}

LexStatus lexSpecialToken(TokenWriter tw, Token token)
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
		return Succeeded;

	case "__EOF__":
		tw.source.eof = true;
		return Succeeded;

	case "__TIME__":
		auto thetime = time(null);
		auto tm = localtime(&thetime);
		token.type = TokenType.StringLiteral;
		token.value = format(`"%02s:%02s:%02s"`, tm.tm_hour, tm.tm_min,
		                     tm.tm_sec);
		tw.addToken(token);
		return Succeeded;

	case "__TIMESTAMP__":
		auto thetime = time(null);
		auto tm = localtime(&thetime);
		token.type = TokenType.StringLiteral;
		token.value = format(`"%s %s %02s %02s:%02s:%02s %s"`,
		                     days[tm.tm_wday], months[tm.tm_mon],
		                     tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec,
		                     1900 + tm.tm_year);
		tw.addToken(token);
		return Succeeded;

	case "__VENDOR__":
		token.type = TokenType.StringLiteral;
		token.value = "N/A";
		tw.addToken(token);
		return Succeeded;
	case "__VERSION__":
		token.type = TokenType.IntegerLiteral;
		token.value = "N/A";
		tw.addToken(token);
		return Succeeded;
	default:
		return lexFailed(tw, "special token");
	}
}

LexStatus lexSymbol(TokenWriter tw)
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
		return lexSingleSymbol(tw, '(', TokenType.OpenParen);
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
		return lexSymbolOrSymbolAssign(tw, ':', TokenType.Colon, TokenType.ColonAssign);
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
		return lexHashLine(tw);
	default:
		return lexFailed(tw, "symbol");
	}
}

LexStatus lexSingleSymbol(TokenWriter tw, dchar c, TokenType symbol)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	if (!match(tw, c)) {
		return Failed;
	}
	token.type = symbol;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return Succeeded;
}

LexStatus lexSymbolOrSymbolAssign(TokenWriter tw, dchar c, TokenType symbol, TokenType symbolAssign)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	auto type = symbol;
	if (!match(tw, c)) {
		return Failed;
	}

	if (matchIf(tw, '=')) {
		type = symbolAssign;
	}

	token.type = type;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);

	return Succeeded;
}

LexStatus lexSymbolOrSymbolAssignOrDoubleSymbol(TokenWriter tw, dchar c, TokenType symbol, TokenType symbolAssign, TokenType doubleSymbol)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	auto type = symbol;
	if (!match(tw, c)) {
		return Failed;
	}

	if (matchIf(tw, '=')) {
		type = symbolAssign;
	} else if (matchIf(tw, c)) {
		type = doubleSymbol;
	}

	token.type = type;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);

	return Succeeded;
}

LexStatus lexCaret(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	token.type = TokenType.Caret;
	if (!match(tw, '^')) {
		return Failed;
	}

	if (matchIf(tw, '=')) {
		token.type = TokenType.CaretAssign;
	} else if (matchIf(tw, '^')) {
		if (matchIf(tw, '=')) {
			token.type = TokenType.DoubleCaretAssign;
		} else {
			token.type = TokenType.DoubleCaret;
		}
	}

	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return Succeeded;
}

LexStatus lexSlash(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	auto type = TokenType.Slash;
	if (!match(tw, '/')) {
		return Failed;
	}

	switch (tw.source.current) {
	case '=':
		if (!match(tw, '=')) {
			return Failed;
		}
		type = TokenType.SlashAssign;
		break;
	case '/':
		return skipLineComment(tw);
	case '*':
		return skipBlockComment(tw);
	case '+':
		return skipNestingComment(tw);
	default:
		break;
	}

	token.type = type;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);

	return Succeeded;
}

LexStatus lexDot(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	auto type = TokenType.Dot;
	if (!match(tw, '.')) {
		return Failed;
	}

	switch (tw.source.current) {
	case '.':
		if (!match(tw, '.')) {
			return Failed;
		}
		if (matchIf(tw, '.')) {
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

	return Succeeded;
}

LexStatus lexLess(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	token.type = TokenType.Less;
	if (!match(tw, '<')) {
		return Failed;
	}

	if (matchIf(tw, '=')) {
		token.type = TokenType.LessAssign;
	} else if (matchIf(tw, '<')) {
		if (matchIf(tw, '=')) {
			token.type = TokenType.DoubleLessAssign;
		} else {
			token.type = TokenType.DoubleLess;
		}
	} else if (matchIf(tw, '>')) {
		if (matchIf(tw, '=')) {
			token.type = TokenType.LessGreaterAssign;
		} else {
			token.type = TokenType.LessGreater;
		}
	}

	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return Succeeded;
}

LexStatus lexGreater(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	token.type = TokenType.Greater;
	if (!match(tw, '>')) {
		return Failed;
	}

	if (matchIf(tw, '=')) {
		token.type = TokenType.GreaterAssign;
	} else if (matchIf(tw, '>')) {
		if (matchIf(tw, '=')) {
			token.type = TokenType.DoubleGreaterAssign;
		} else if (matchIf(tw, '>')) {
			if (matchIf(tw, '=')) {
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
	return Succeeded;
}

LexStatus lexBang(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	token.type = TokenType.Bang;
	if (!match(tw, '!')) {
		return Failed;
	}

	if (matchIf(tw, '=')) {
		token.type = TokenType.BangAssign;
	} else if (matchIf(tw, '>')) {
		if (tw.source.current == '=') {
			token.type = TokenType.BangGreaterAssign;
		} else {
			token.type = TokenType.BangGreater;
		}
	} else if (matchIf(tw, '<')) {
		if (matchIf(tw, '>')) {
			if (matchIf(tw, '=')) {
				token.type = TokenType.BangLessGreaterAssign;
			} else {
				token.type = TokenType.BangLessGreater;
			}
		} else if (matchIf(tw, '=')) {
			token.type = TokenType.BangLessAssign;
		} else {
			token.type = TokenType.BangLess;
		}
	}

	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return Succeeded;
}

// Escape sequences are not expanded inside of the lexer.

LexStatus lexCharacter(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	if (!match(tw, '\'')) {
		return Failed;
	}
	while (tw.source.current != '\'') {
		if (tw.source.eof) {
			return lexExpected(tw, token.loc, "`'`");
		}
		if (matchIf(tw, '\\')) {
			tw.source.next();
		} else {
			tw.source.next();
		}
	}
	if (!match(tw, '\'')) {
		return Failed;
	}

	token.type = TokenType.CharacterLiteral;
	token.value = tw.source.sliceFrom(mark);
	if (token.value.length > 4 && token.value[0 .. 3] == "'\\0") {
		return lexUnsupported(tw, token.loc, "octal char literals");
	}
	tw.addToken(token);
	return Succeeded;
}

LexStatus lexString(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	dchar terminator;
	bool raw;
	bool postfix = true;

	if (matchIf(tw, 'r')) {
		raw = true;
		terminator = '"';
	} else if (tw.source.current == 'q') {
		return lexQString(tw);
	} else if (matchIf(tw, 'x')) {
		raw = false;
		terminator = '"';
	} else if (tw.source.current == '`') {
		raw = true;
		terminator = '`';
	} else if (tw.source.current == '"') {
		raw = false;
		terminator = '"';
	} else {
		return lexFailed(tw, "string");
	}

	if (!match(tw, terminator)) {
		return Failed;
	}
	while (tw.source.current != terminator) {
		if (tw.source.eof) {
			return lexExpected(tw, token.loc, "string literal terminator");
		}
		if (!raw && matchIf(tw, '\\')) {
			tw.source.next();
		} else {
			tw.source.next();
		}
	}
	if (!match(tw, terminator)) {
		return Failed;
	}
	dchar postfixc = tw.source.current;
	if ((postfixc == 'c' || postfixc == 'w' || postfixc == 'd') && postfix) {
		if (!match(tw, postfixc)) {
			return Failed;
		}
	}

	token.type = TokenType.StringLiteral;
	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);

	return Succeeded;
}

LexStatus lexQString(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	token.type = TokenType.StringLiteral;
	auto mark = tw.source.save();
	bool leof;
	if (tw.source.lookahead(1, leof) == '{') {
		return lexTokenString(tw);
	}
	if (!match(tw, "q\"")) {
		return Failed;
	}

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
			encode(buf, tw.source.current);
			tw.source.next();
			while (isdalpha(tw.source.current, Position.MiddleOrEnd)) {
				encode(buf, tw.source.current);
				tw.source.next();
			}
			if (!match(tw, '\n')) {
				return Failed;
			}
			version (Volt) {
				identdelim = cast(string)new buf[0 .. $];
			} else {
				identdelim = buf.idup;
			}
		} else {
			opendelimiter = tw.source.current;
			closedelimiter = tw.source.current;
		}
	}

	if (identdelim is null && !match(tw, opendelimiter)) {
		return Failed;
	}
	int nest = 1;
	while (true) {
		if (tw.source.eof) {
			return lexExpected(tw, token.loc, "string literal terminator");
		}
		if (matchIf(tw, opendelimiter)) {
			nest++;
		} else if (matchIf(tw, closedelimiter)) {
			nest--;
			if (nest == 0) {
				if (!match(tw, '"')) {
					return Failed;
				}
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
					return lexExpected(tw, token.loc, "string literal terminator");
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
			if (!match(tw, '"')) {
				return Failed;
			}
			break;
		} else if (matchIf(tw, closedelimiter)) {
			if (!match(tw, '"')) {
				return Failed;
			}
			break;
		}
	}

	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return Succeeded;
}

LexStatus lexTokenString(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	token.type = TokenType.StringLiteral;
	auto mark = tw.source.save();
	if (!match(tw, "q{")) {
		return Failed;
	}
	auto dummystream = new TokenWriter(tw.source);

	int nest = 1;
	while (nest > 0) {
		auto succeeded = lexNext(dummystream);
		if (!succeeded) {
			return lexExpected(tw, "token");
		}
		switch (dummystream.lastAdded.type) {
		case TokenType.OpenBrace:
			nest++;
			break;
		case TokenType.CloseBrace:
			nest--;
			break;
		case TokenType.End:
			return lexExpected(tw, "end of token string literal");
		default:
			break;
		}
	}

	token.value = tw.source.sliceFrom(mark);
	tw.addToken(token);
	return Succeeded;
}

/**
 * Consume characters from the source from the characters array until you can't.
 * Returns: the number of characters consumed, not counting underscores.
 */
size_t consume(Source src, scope const(dchar)[] characters...)
{
	size_t consumed;
	static bool isIn(scope const(dchar)[] chars, dchar arg) {
		foreach (dchar c; chars) {
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
 * Lex an integer literal and add the resulting token to tw.
 * If it detects the number is floating point, it will call lexReal directly.
 */
LexStatus lexNumber(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto src = new Source(tw.source);
	auto mark = src.save();
	bool tmp;

	bool hex;
	if (src.current == '0') {
		src.next();
		if (src.current == 'b' || src.current == 'B') {
			// Binary literal.
			src.next();
			auto consumed = consume(src, '0', '1', '_');
			if (consumed == 0) {
				return lexExpected(tw, src.loc, "binary digit");
			}
		} else if (src.current == 'x' || src.current == 'X') {
			// Hexadecimal literal.
			src.next();
			hex = true;
			if (src.current == '.' || src.current == 'p' || src.current == 'P') return lexReal(tw);
			auto consumed = consume(src, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
			                             'a', 'b', 'c', 'd', 'e', 'f',
			                             'A', 'B', 'C', 'D', 'E', 'F', '_');
			if ((src.current == '.' && src.lookahead(1, tmp) != '.') || src.current == 'p' || src.current == 'P') return lexReal(tw);
			if (consumed == 0) {
				return lexExpected(tw, src.loc, "hexadecimal digit");
			}
		} else if (src.current == '1' || src.current == '2' || src.current == '3' || src.current == '4' || src.current == '5' ||
				src.current == '6' || src.current == '7') {
			/* This used to be an octal literal, which are gone.
			 * DMD treats this as an error, so we do too.
			 */
			return lexUnsupported(tw, src.loc, "octal literals");
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
		return lexExpected(tw, src.loc, "integer literal");
	}

	if (src.current == 'f' || src.current == 'F' || src.current == 'e' || src.current == 'E') {
		return lexReal(tw);
	}

	tw.source.sync(src);
	bool dummy;
	auto _1 = tw.source.current;
	auto _2 = tw.source.lookahead(1, dummy);
	if ((_1 == 'i' || _1 == 'u') && isDigit(_2)) {
		tw.source.next();  // i/u
		if (isDigit(tw.source.current)) tw.source.next();
		if (isDigit(tw.source.current)) tw.source.next();
	} else if (tw.source.current == 'U' || tw.source.current == 'u') {
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
	tw.addToken(token);

	return Succeeded;
}

/// Lex a floating literal and add the resulting token to tw.
LexStatus lexReal(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	auto mark = tw.source.save();
	bool skipRealPrologue;

	LexStatus stop()
	{
		token.type = TokenType.FloatLiteral;
		token.value = tw.source.sliceFrom(mark);
		tw.addToken(token);
		return Succeeded;
	}

	if (tw.source.current == '.') {
		// .n
		tw.source.next();
		if (!isDigit(tw.source.current)) {
			return lexExpected(tw, "digit after decimal point");
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
				return lexExpected(tw, "hexadecimal digit");
			}
			if (tw.source.current == 'p' || tw.source.current == 'P') {
				tw.source.next();
				if (tw.source.current == '+' || tw.source.current == '-') {
					tw.source.next();
				}
				skipRealPrologue = true;
			} else {
				return lexExpected(tw, "exponent");
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
				if (!match(tw, '.')) {
					return Failed;
				}
				consume(tw.source, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_');
				if (tw.source.current == 'L' || tw.source.current == 'f' || tw.source.current == 'F') {
					tw.source.next();
					return stop();
				}
			} else {
				return lexExpected(tw, "non-zero digit, '_', or decimal point");
			}
		}
	} else if (isDigit(tw.source.current)) {
		// n.n
		consume(tw.source, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_');
		if (!match(tw, '.')) {
			return Failed;
		}
		consume(tw.source, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_');
		if (tw.source.current == 'L' || tw.source.current == 'f' || tw.source.current == 'F') {
			tw.source.next();
			return stop();
		}
	} else {
		return lexExpected(tw, "floating point literal");
	}

	if (tw.source.current == 'e' || tw.source.current == 'E' || skipRealPrologue) {
		if (!skipRealPrologue) {
			tw.source.next();
			if (tw.source.current == '+' || tw.source.current == '-') {
				tw.source.next();
			}
		}
		if (!isDigit(tw.source.current)) {
			return lexExpected(tw, "digit");
		}
		consume(tw.source, '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '_');
		if (tw.source.current == 'L' || tw.source.current == 'f' || tw.source.current == 'F') {
			tw.source.next();
		}
	}

	return stop();
}

LexStatus lexHashLine(TokenWriter tw)
{
	auto token = currentLocationToken(tw);
	if (!match(tw, '#')) {
		return Failed;
	}

	if (match(tw, "run")) {
		if (!isWhite(tw.source.current)) {
			return lexExpected(tw, token.loc, "#run");
		}

		token.type = TokenType.HashRun;
		token.value = "#run";
		tw.addToken(token);
		return Succeeded;
	}

	if (!match(tw, "line")) {
		return Failed;
	}

	tw.source.skipWhitespace();

	if (!lexNumber(tw)) {
		return Failed;
	}
	Token Int = tw.lastAdded;
	if (Int.type != TokenType.IntegerLiteral) {
		return lexExpected(tw, Int.loc, "integer literal");
	}
	int lineNumber = toInt(Int.value);
	tw.pop();

	tw.source.skipWhitespace();

	// Why yes, these do use a magical kind of string literal. Thanks for noticing! >_<
	if (!match(tw, '"')) {
		return Failed;
	}
	char[] buf;
	while (tw.source.current != '"') {
		encode(buf, tw.source.next());
	}
	if (!match(tw, '"')) {
		return Failed;
	}
	string filename = cast(string)buf;

	assert(lineNumber >= 0);
	if (lineNumber == 0) {
		return lexExpected(tw, "line number greater than zero");
	}
	tw.source.changeCurrentLocation(filename, cast(size_t)lineNumber);

	tw.source.skipWhitespace();

	return Succeeded;
}
