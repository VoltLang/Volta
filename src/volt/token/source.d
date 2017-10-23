/*#D*/
// Copyright © 2010, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.token.source;

import watt.io.file : read;
import watt.text.utf : decode, validate;
import watt.text.ascii : isWhite;
import watt.text.format : format;

import volt.errors : panic;
import volt.token.location : Location;


alias Mark = size_t;


/*!
 * Class for handling reading of Volt source code.
 *
 * Upon loading or getting source the ctor will validate the source
 * code to make sure that it is Utf-8 and the BOM is valid.
 */
final class Source
{
public:
	//! Source code, validated utf8 by constructors.
	string source;
	//! The location of the current character @p mChar.
	Location loc;
	//! Have we reached EOF, if we have current = dchar.init.
	bool eof = false;

private:
	//! The current unicode character.
	dchar mChar;
	//! Pointer into the string for the next character.
	size_t mNextIndex;
	//! The index for mChar
	size_t mLastIndex;

public:
	/*!
	 * Sets the source to string and the current location
	 * and validate it as a utf8 source.
	 *
	 * Side-effects:
	 *   Puts all the other fields into known good states.
	 *
	 * Throws:
	 *   UtfException if the source is not valid utf8.
	 */
	this(string s, string filename)
	{
		source = s;
		checkBOM();
		validate(source);

		next();

		loc.filename = filename;
		loc.line = 1;
	}

	/*!
	 * Copy contructor, same as @p dup.
	 */
	this(Source src)
	{
		this.source = src.source;
		this.loc = src.loc;
		this.eof = src.eof;
		this.mChar = src.mChar;
		this.mNextIndex = src.mNextIndex;
		this.mLastIndex = src.mLastIndex;
	}

	/*!
	 * Validate that the current start of source has a valid utf8 BOM.
	 *
	 * Side-effects:
	 *   @p source advanced to after valid utf8 BOM if found.
	 *
	 * Throws:
	 *   CompilerPanic if source if BOM is not valid.
	 */
	void checkBOM()
	{
		if (source.length >= 2 && source[0 .. 2] == cast(string)[0xFE, 0xFF] ||
		    source.length >= 2 && source[0 .. 2] == cast(string)[0xFF, 0xFE] ||
		    source.length >= 4 && source[0 .. 4] == cast(string)[0x00, 0x00, 0xFE, 0xFF] ||
		    source.length >= 4 && source[0 .. 4] == cast(string)[0xFF, 0xFE, 0x00, 0x00]) {
			assert(false, "only UTF-8 input is supported.");
		}

		if (source.length >= 3 && source[0 .. 3] == cast(string)[0xEF, 0xBB, 0xBF]) {
			source = source[3 .. $];
		}
	}

	/*!
	 * Set the loc to newFilename(line:1).
	 */
	void changeCurrentLocation(string newFilename, size_t newLine)
	{
		loc.filename = newFilename;
		loc.line = newLine;
		return;
	}

	/*!
	 * Used to skip the first script line in D sources.
	 *
	 * Side-effects:
	 *   @arg @see next
	 */
	void skipScriptLine()
	{
		bool lookEOF = false;

		if (mChar != '#' || lookahead(1, /*#out*/lookEOF) != '!') {
			return;
		}

		// We have a script line start, read the rest of the line.
		skipEndOfLine();
	}

	/*!
	 * Used to skip whitespace in the source file,
	 * as defined by watt.text.ascii.isWhite.
	 *
	 * Side-effects:
	 *   @arg @see next
	 */
	void skipWhitespace()
	{
		while (isWhite(mChar) && !eof) {
			next();
		}
	}

	/*!
	 * Skips till character after next end of line or eof.
	 *
	 * Side-effects:
	 *   @arg @see next
	 */
	void skipEndOfLine()
	{
		while (mChar != '\n' && !eof) {
			next();
		}
	}

	dchar decodeChar()
	{
		size_t tmpIndex = mNextIndex;
		return decodeChar(/*#ref*/tmpIndex);
	}

	dchar decodeChar(ref size_t index)
	{
		if (index >= source.length) {
			return dchar.init;
		}

		return decode(source, /*#ref*/index);
	}

	/*!
	 * Get the next unicode character.
	 *
	 * Side-effects:
	 *   @p eof set to true if we have reached the EOF.
	 *   @p mChar is set to the returned character if not at EOF.
	 *   @p mIndex advanced to the end of the given character.
	 *   @p loc updated to the current position if not at EOF.
	 *
	 * Throws:
	 *   UtfException if the source is not valid utf8.
	 *
	 * Returns:
	 *   Returns next unicode char or dchar.init at EOF.
	 */
	dchar next()
	{
		if (mChar == '\n') {
			loc.line++;
			loc.column = 0;
		}

		mLastIndex = mNextIndex;
		mChar = decodeChar(/*#ref*/mNextIndex);
		if (mChar == dchar.init) {
			eof = true;
			mNextIndex = source.length;
			mLastIndex = mNextIndex;
			return mChar;
		}

		loc.column++;

		return mChar;
	}

	/*!
	 * Returns the current utf8 char.
	 *
	 * Side-effects:
	 *   None.
	 */
	@property dchar current()
	{
		return mChar;
	}

	/*!
	 * Return the unicode character @p n chars forwards.
	 * @p lookaheadEOF set to true if we reached EOF, otherwise false.
	 *
	 * Throws:
	 *   UtfException if the source is not valid utf8.
	 *
	 * Side-effects:
	 *   None.
	 *
	 * Returns:
	 *   Unicode char at @p n or @p dchar.init at EOF.
	 */
	dchar lookahead(size_t n, out bool lookaheadEOF)
	{
		if (n == 0) {
			lookaheadEOF = eof;
			return mChar;
		}

		dchar c;
		auto index = mNextIndex;
		for (size_t i; i < n; i++) {
			c = decodeChar(/*#ref*/index);
			if (c == dchar.init) {
				lookaheadEOF = true;
				return dchar.init;
			}
		}
		return c;
	}

	/*!
	 * Returns a index for the current loc.
	 *
	 * Side-effects:
	 *   None.
	 */
	Mark save()
	{
		return mLastIndex;
	}

	/*!
	 * Get a slice from the current token to @p mark.
	 * @p mark must before current token.
	 *
	 * Side-effects:
	 *   None.
	 */
	string sliceFrom(Mark mark)
	{
		return source[mark .. mLastIndex];
	}

	/*!
	 * Synchronise this source with a duplicated one.
	 *
	 * Throws:
	 *   CompilerPanic if the source file is not the same for both sources.
	 *
	 * Side-effects:
	 *   None.
	 */
	void sync(Source src)
	{
		if (src.source !is this.source) {
			throw panic(
				"attempted to sync different sources");
		}
		this.loc = src.loc;
		this.mNextIndex = src.mNextIndex;
		this.mLastIndex = src.mLastIndex;
		this.mChar = src.mChar;
		this.eof = src.eof;
	}
}
