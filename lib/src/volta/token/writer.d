/*#D*/
// Copyright © 2010-2012, Bernard Helyer.  All rights reserved.
// Copyright © 2011, Jakob Ovrum.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.token.writer;

import volta.interfaces;
import volta.token.error;
import volta.token.source;
import volta.ir.tokenstream;


/*!
 * Small container class for tokens, used by the lexer to write tokens to.
 */
final class TokenWriter
{
public:
	LexerError[] errors;
	bool noDoc;
	ErrorSink errSink;

	bool magicFlagD;

private:
	Source mSource;
	size_t mLength;
	Token[] mTokens;

public:
	/*!
	 * Create a new TokenWriter and initialize
	 * the first token to TokenType.Begin.
	 */
	this(Source source)
	{
		this.mSource = source;
		this.errSink = errSink;
		initTokenArray();
	}

	/*!
	 * Return the current source.
	 *
	 * Side-effects:
	 *   None.
	 */
	@property Source source()
	{
		return mSource;
	}

	/*!
	 * Add the
	 * Return the last added token.
	 *
	 * Side-effects:
	 *   None.
	 */
	void addToken(Token token)
	{
		if (mTokens.length <= mLength) {
			auto tokens = new Token[](mLength * 2 + 3);
			tokens[0 .. mLength] = mTokens[];
			mTokens = tokens;
		}

		mTokens[mLength++] = token;
		token.loc.length = token.value.length;
	}

	/*!
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
		mLength--;
	}

	/*!
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

	/*!
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

private:
	/*!
	 * Create a Begin token add set the token array
	 * to single array only containing it.
	 *
	 * Side-effects:
	 *   mTokens is replaced, current source is left untouched.
	 */
	void initTokenArray()
	{
		Token start;
		start.type = TokenType.Begin;
		start.value = "START";

		// Reset the token array
		mTokens = new Token[](1);
		mTokens[0] = start;
		mLength = 1;
		return;
	}
}
