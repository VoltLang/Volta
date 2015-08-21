// Copyright © 2010-2012, Bernard Helyer.  All rights reserved.
// Copyright © 2011, Jakob Ovrum.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.token.writer;

import volt.token.source;
import volt.token.stream;
import volt.token.lexererror;


/**
 * Small container class for tokens, used by the lexer to write tokens to.
 */
final class TokenWriter
{
public:
	LexerError[] errors;

private:
	Source mSource;
	size_t mLength;
	Token[] mTokens;

public:
	/**
	 * Create a new TokenWriter and initialize
	 * the first token to TokenType.Begin.
	 */
	this(Source source)
	{
		this.mSource = source;
		initTokenArray();
	}

	/**
	 * Return the current source.
	 *
	 * Side-effects:
	 *   None.
	 */
	@property Source source()
	{
		return mSource;
	}

	/**
	 * Add the
	 * Return the last added token.
	 *
	 * Side-effects:
	 *   None.
	 */
	void addToken(Token token)
	in {
		assert(token !is null);
	}
	body {
		if (mTokens.length <= mLength) {
			auto tokens = new Token[](mLength * 2 + 3);
			tokens[0 .. mLength] = mTokens[];
			mTokens = tokens;
		}

		mTokens[mLength++] = token;
		token.location.length = token.value.length;
	}

	/**
	 * Remove the last token from the token list.
	 * No checking is performed, assumes you _know_ that you can remove a token.
	 *
	 * Side-effects:
	 *   mTokens is shortened by one.
	 */
	void pop()
	in {
		assert(mLength > 0);
	}
	body {
		mTokens[--mLength] = null;
	}

	/**
	 * Return the last added token.
	 *
	 * Side-effects:
	 *   None.
	 */
	@property Token lastAdded()
	in {
		assert(mLength > 0);
	}
	body {
		return mTokens[mLength - 1];
	}

	/**
	 * Returns this writer's tokens.
	 *
	 * TODO: Currently this function will leave the writer in a bit of a
	 *       odd state. Since it resets the tokens but not the source.
	 *
	 * Side-effects:
	 *   Remove all tokens from this writer, and reinitializes the writer.
	 */
	Token[] getTokens()
	{
		auto ret = new Token[](mLength);
		ret[] = mTokens[0 .. mLength];
		initTokenArray();
		return ret;
	}

	/**
	 * Set the location to newFilename(line:1).
	 *
	 * Side-effects:
	 *   Updates the attached source location field.
	 */
	void changeCurrentLocation(string newFilename, size_t newLine)
	{
		mSource.location.filename = newFilename;
		mSource.location.line = newLine;
		return;
	}

private:
	/**
	 * Create a Begin token add set the token array
	 * to single array only containing it.
	 *
	 * Side-effects:
	 *   mTokens is replaced, current source is left untouched.
	 */
	void initTokenArray()
	{
		auto start = new Token();
		start.type = TokenType.Begin;
		start.value = "START";

		// Reset the token array
		mTokens = new Token[](1);
		mTokens[0] = start;
		mLength = 1;
		return;
	}
}
