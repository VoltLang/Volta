// Copyright © 2010, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.token.source;

import std.file : read;
import std.utf : validate, decode;
import std.string : format;

import volt.exceptions : CompilerPanic;
import volt.token.location : Location;

alias size_t Mark;


/**
 * Class for handling reading of D source code.
 *
 * Upon loading or getting source the ctor will validate the source
 * code to make sure that it is Utf-8 and the BOM is valid.
 */
class Source
{
public:
	/// Source code, validated utf8 by constructors.
	string source;
	/// The location of the current character @p mChar.
	Location location;
	/// Have we reached EOF, if we have current = dchar.init.
	bool eof = false;

private:
	/// The current unicode character.
	dchar mChar;
	/// Pointer into the string for the next character.
	size_t mIndex;

public:
	/**
	 * Open the given file and validate it as a utf8 source.
	 *
	 * Side-effects:
	 *   Puts all the other fields into known good states.
	 *
	 * Throws:
	 *   CompilerPanic if source BOM is not valid.
	 *   UtfException if source is not utf8.
	 */
	this(string filename)
	{
		source = cast(string)read(filename);
		location.filename = filename;
		location.line = 1;
		location.column = 1;

		this(source, location);

		skipScriptLine();
	}

	/**
	 * Sets the source to string and the current location
	 * and validate it as a utf8 source.
	 *
	 * Side-effects:
	 *   Puts all the other fields into known good states.
	 *
	 * Throws:
	 *   UtfException if the source is not valid utf8.
	 */
	this(string s, Location location)
	{
		source = s;
		checkBOM();
		validate(source);

		next();

		this.location = location;
	}

	/**
	 * Copy contructor, same as @p dup.
	 */
	this(Source src)
	{
		this.source = src.source;
		this.location = src.location;
		this.eof = src.eof;
		this.mChar = src.mChar;
		this.mIndex = src.mIndex;
	}

	/**
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
			throw new CompilerPanic("only UTF-8 input is supported.");
		}

		if (source.length >= 3 && source[0 .. 3] == cast(string)[0xEF, 0xBB, 0xBF]) {
			source = source[3 .. $];
		}
	}

	/**
	 * Used to skip the first script line in D sources.
	 *
	 * Side-effects:
	 *   @arg @see next
	 */
	void skipScriptLine()
	{
		bool lookEOF = false;

		if (mChar != '#' || lookahead(1, lookEOF) != '!')
			return;

		// We have a script line start, read the rest of the line.
		while (next() != '\n' && !eof) {}
	}

	/**
	 * Get the next unicode character.
	 *
	 * Side-effects:
	 *   @p eof set to true if we have reached the EOF.
	 *   @p mChar is set to the returned character if not at EOF.
	 *   @p mIndex advanced to the end of the given character.
	 *   @p location updated to the current position if not at EOF.
	 *
	 * Throws:
	 *   UtfException if the source is not valid utf8.
	 *
	 * Returns:
	 *   Returns next unicode char or dchar.init at EOF.
	 */
	dchar next()
	{
		if (mIndex >= source.length) {
			eof = true;
			mChar = dchar.init;
			return mChar;
		}

		if (mChar == '\n') {
			location.line++;
			location.column = 0;
		}

		mChar = decode(source, mIndex);
		location.column++;

		return mChar;
	}

	/**
	 * Returns the current utf8 char.
	 *
	 * Side-effects:
	 *   None.
	 */
	dchar current()
	{
		return mChar;
	}

	/**
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
		if (n == 0) return mChar;

		size_t tmpIndex = mIndex;
		for(int i; i < n; i++) {
			dchar c = decode(source, tmpIndex);
			if (tmpIndex >= source.length) {
				lookaheadEOF = true;
				return dchar.init;
			}
			if (i == n - 1) {
				return c;
			}
		}
		assert(false);
	}

	/**
	 * Returns a index for the current location.
	 *
	 * Side-effects:
	 *   None.
	 */
	Mark save()
	{
		return mIndex - 1;
	}

	/**
	 * Get a slice from the current token to @p mark.
	 * @p mark must before current token.
	 *
	 * Side-effects:
	 *   None.
	 */
	string sliceFrom(Mark mark)
	{
		return source[mark .. mIndex - 1];
	}

	/**
	 * Make a new Source object in the same state as this one.
	 *
	 * Side-effects:
	 *   None.
	 */
	Source dup()
	{
		return new Source(this);
	}

	/**
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
			throw new CompilerPanic(
				"attempted to sync different sources");
		}
		this.location = src.location;
		this.mIndex = src.mIndex;
		this.mChar = src.mChar;
		this.eof = src.eof;
	}
}
