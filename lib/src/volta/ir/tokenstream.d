/*#D*/
// Copyright 2010, Jakob Ovrum.
// Copyright 2010-2018, Bernard Helyer.
// Copyright 2012-2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volta.ir.tokenstream;

public import volta.ir.token;

import volta.interfaces : ErrorSink;
import volta.errors;


/*!
 * Class used by the parser to read lexed tokens.
 */
class TokenStream
{
public:
	ErrorSink errSink;

protected:
	Token[] mTokens;
	size_t mIndex;

public:
	/*!
	 * Takes the token array, initializes mTokens and 
	 * sets the current token to the first token.
	 */
	this(Token[] tokens, ErrorSink errSink)
	{
		this.errSink = errSink;
		this.mTokens = tokens;
	}

	/*!
	 * Reset the stream.
	 *
	 * Side-effects:
	 *   Sets mIndex = 0.
	 */
	final void reset()
	{
		mIndex = 0;
	}

	/*!
	 * Compares the current token's type against the given type.
	 *
	 * Side-effects:
	 *   None.
	 */
	final bool opEquals(TokenType type)
	{
		return type == peek.type;
	}

	/*!
	 * Compares from the current token and onwards type against
	 * the list of types.
	 *
	 * Side-effects:
	 *   None.
	 */
	final int opEquals(scope const(TokenType)[] types)
	in {
		if (types.length == 0) {
			panic(errSink, "Empty types array passed to opEquals.");
		}
	}
	do {
		foreach (i, right; types) {
			bool eof;
			TokenType left = lookahead(i, /*#out*/eof).type;
			if (left != right && !eof)
				return 0;
		}
		return 1;
	}

	/*!
	 * Returns the current token.
	 *
	 * Side-effects:
	 *   None.
	 */
	final @property Token peek()
	{
		return mTokens[mIndex];
	}

	/*!
	 * Returns the current token. @see lookbehind.
	 *
	 * Thorws:
	 *   CompilerPanic on mIndex == 0.
	 *
	 * Side-effects:
	 *   None.
	 */
	final @property Token previous()
	{
		return lookbehind(1);
	}

	/*!
	 * Returns the token @n steps ahead. Will clamp @n to stream length.
	 *
	 * Side-effects:
	 *   None.
	 */
	final Token lookahead(size_t n, out bool eof)
	{
		if (n == 0) {
			return peek;
		}
		auto index = mIndex + n;
		if (index >= mTokens.length) {
			eof = true;
			return mTokens[$-1];
		}

		return mTokens[index];
	}

	/*!
	 * Returns the token @n step behind the current token. Will cause
	 * a compiler panic if looking to far back.
	 *
	 * Throws:
	 *   CompilerPanic on @n being larger then mIndex.
	 *
	 * Side-effects:
	 *   None.
	 */
	final Token lookbehind(size_t n)
	{
		if (n > mIndex) {
			panic(errSink, "Token array access out of bounds.");
		}
		return mTokens[mIndex - n];
	}

	/*!
	 * Returns the current position in the stream.
	 *
	 * Side-effects:
	 *   None.
	 */
	final size_t save()
	{
		return mIndex;
	}

	/*!
	 * Restore the stream to the current index retrieved from save().
	 *
	 * Side-effects:
	 *   mIndex is set to index.
	 */
	final void restore(size_t index)
	{
		if (index >= mTokens.length) {
			panic(errSink, "Bad restore index.");
		}
		mIndex = index;
	}
}
