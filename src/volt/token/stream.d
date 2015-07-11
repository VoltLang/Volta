// Copyright © 2010-2011, Bernard Helyer.  All rights reserved.
// Copyright © 2010, Jakob Ovrum.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.token.stream;

version(Volt) {
	import watt.text.string : strip, indexOf;
} else {
	import std.string : strip, indexOf;
}

import volt.errors : panic, makeStrayDocComment, makeExpected;
public import volt.token.token;


/**
 * Class used by the parser to read lexed tokens.
 */
final class TokenStream
{
public:
	Token lastDocComment;
	string* retroComment;  ///< For backwards doc comments (like this one).
	int multiDepth;

private:
	Token[] mTokens;
	size_t mIndex;
	string[] mComment;

public:
	/**
	 * Takes the token array does some error checking and initializes
	 * mTokens with it also sets the current token to the first token.
	 *
	 * Throws:
	 *   CompilerPanic if token stream is not valid.
	 */
	this(Token[] tokens)
	{
		if (tokens.length < 3)
			throw panic("Token stream too short");
		if (tokens[0].type != TokenType.Begin)
			throw panic("Token stream not started correctly");
		if (tokens[$-1].type != TokenType.End)
			throw panic("Token stream not terminated correctly");

		pushCommentLevel();

		this.mTokens = tokens;
	}

	/**
	 * Reset the stream.
	 *
	 * Side-effects:
	 *   Sets mIndex = 0.
	 */
	void reset()
	{
		mIndex = 0;
	}

	/**
	 * Get the current token and advances the stream to the next token.
	 *
	 * Side-effects:
	 *   Increments mIndex.
	 */
	Token get()
	{
		doDocCommentBlocks();
		auto retval = mTokens[mIndex];
		if (mIndex < mTokens.length - 1) {
			mIndex++;
		}
		return retval;
	}

	/**
	 * Compares the current token's type against the given type.
	 *
	 * Side-effects:
	 *   None.
	 */
	bool opEquals(TokenType type)
	{
		return type == peek().type;
	}

	/**
	 * Compares from the current token and onwards type against
	 * the list of types.
	 *
	 * Side-effects:
	 *   None.
	 */
	int opEquals(TokenType[] types)
	in {
		assert(types.length > 0);
	}
	body {
		foreach(uint i, right; types) {
			TokenType left = lookahead(i).type;
			if (left != right)
				return 0;
		}
		return 1;
	}

	/**
	 * Returns the current token.
	 *
	 * Side-effects:
	 *   None.
	 */
	Token peek()
	{
		return mTokens[mIndex];
	}

	/**
	 * Returns the current token. @see lookbehind.
	 *
	 * Thorws:
	 *   CompilerPanic on mIndex == 0.
	 *
	 * Side-effects:
	 *   None.
	 */
	Token previous()
	{
		return lookbehind(1);
	}

	/**
	 * Returns the token @n steps ahead. Will clamp @n to stream length.
	 *
	 * Side-effects:
	 *   None.
	 */
	Token lookahead(size_t n)
	{
		if (n == 0) {
			return peek();
		}
		auto index = mIndex + n;
		if (index >= mTokens.length) {
			return mTokens[$-1];
		}

		return mTokens[index];
	}

	/**
	 * Returns the token @n step behind the current token. Will cause
	 * a compiler panic if looking to far back.
	 *
	 * Throws:
	 *   CompilerPanic on @n being larger then mIndex.
	 *
	 * Side-effects:
	 *   None.
	 */
	Token lookbehind(size_t n)
	{
		if (n > mIndex)
			throw panic("Token array access out of bounds");
		return mTokens[mIndex - n];
	}

	/**
	 * Returns the current position in the stream.
	 *
	 * Side-effects:
	 *   None.
	 */
	size_t save()
	{
		return mIndex;
	}

	/**
	 * Restore the stream to the current index retrieved from save().
	 *
	 * Side-effects:
	 *   mIndex is set to index.
	 */
	void restore(size_t index)
	{
		assert(index < mTokens.length);
		mIndex = index;
	}

	void pushCommentLevel()
	{
		if (inMultiCommentBlock && mComment.length > 0) {
			auto oldComment = mComment[$-1];
			mComment ~= oldComment;
		} else {
			mComment ~= [""];
		}
	}

	void popCommentLevel()
	{
		assert(mComment.length > 0);
		string oldComment;
		if (inMultiCommentBlock) {
			oldComment = mComment[$-1];
		}
		if (mComment[$-1].length && !inMultiCommentBlock) {
			assert(lastDocComment !is null);
			auto e = makeStrayDocComment(lastDocComment.location);
			e.neverIgnore = true;
			throw e;
		}
		if (mComment.length >= 0) {
			mComment[$-1] = oldComment;
		}
	}

	/// Add a comment to the current comment level.
	void addComment(Token comment)
	{
		assert(comment.type == TokenType.DocComment);
		auto raw = strip(comment.value);
		if (raw == "@{" || raw == "@}") {
			return;
		}
		mComment[$-1] ~= comment.value;
		lastDocComment = comment;
	}

	/// Retrieve and clear the current comment.
	string comment()
	{
		assert(mComment.length >= 1);
		auto str = mComment[$-1];
		if (!inMultiCommentBlock) {
			mComment[$-1] = "";
		}
		return str;
	}

	/**
	 * True if we found @ { on its own, so apply the last doccomment
	 * multiple times, until we see a matching number of @ }s.
	 */
	@property bool inMultiCommentBlock()
	{
		return multiDepth > 0;
	}

private:

	void doDocCommentBlocks()
	{
		if (mTokens[mIndex].type != TokenType.DocComment) {
			return;
		}
		auto openIndex = mTokens[mIndex].value.indexOf("@{");
		if (openIndex >= 0) {
			auto precomment = strip(mTokens[mIndex].value[0 .. openIndex]);
			if (precomment.length > 0) {
				mComment[$-1] ~= precomment;
			}
			multiDepth++;
			return;
		}
		if (mTokens[mIndex].value.indexOf("@}") >= 0) {
			if (!inMultiCommentBlock) {
				auto e = makeExpected(mTokens[mIndex].location, "@{");
				e.neverIgnore = true;
				throw e;
			}
			multiDepth--;
			if (multiDepth == 0 && mComment.length > 0) {
				mComment[$-1] = "";
			}
		}
	}
}
