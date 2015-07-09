// Copyright © 2010, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.exceptions;

version(Volt) {
	import watt.io : writefln;
	import watt.text.format : format;
} else {
	import std.stdio : writefln;
	import std.string : format;
}

import volt.token.location;


/**
 * Base class for compiler exceptions.
 */
abstract class CompilerException : Exception
{
public:
	Location location;
	bool hasLocation = false;

	/**
	 * This error is not to be swallowed when retrying
	 * a parse as a different construct.
	 *
	 * This is only used when parsing statements as the
	 * fallback case to discriminate between declarations
	 * and expressions.
	 *
	 * Not fond of this, but this allows us to emit diagnostics 
	 * from the declaration parser that are much more directed
	 * than the failure the expression parser would give.
	 */
	bool neverIgnore = false;

	CompilerError more; // Optional
	string fixHint; // Optional

public:
	this(string message, CompilerError more, bool neverIgnore, string file = __FILE__, size_t line = __LINE__)
	{
		this.more = more;
		this.neverIgnore = neverIgnore;
		super(format(errorFormat(), message), file, line);
	}

	this(Location loc, string message, CompilerError more, bool neverIgnore, string file = __FILE__, size_t line = __LINE__)
	{
		this.more = more;
		this.location = loc;
		this.hasLocation = true;
		this.neverIgnore = neverIgnore;
		super(format(locationFormat(), loc.toString(), message), file, line);
	}

protected:
	string errorFormat()
	{
		return "error: %s";
	}

	string locationFormat()
	{
		return "%s: error: %s";
	}
}

/**
 * Exception for compiler error messages arising from source code.
 *
 * Is subclassed by more specialized error messages.
 */
class CompilerError : CompilerException
{
	this(string message, string file = __FILE__, size_t line = __LINE__)
	{
		super(message, null, false, file, line);
	}

	this(string message, CompilerError more, string file = __FILE__, size_t line = __LINE__)
	{
		super(message, more, false, file, line);
	}

	this(Location loc, string message, bool neverIgnore, string file = __FILE__, size_t line = __LINE__)
	{
		super(loc, message, null, neverIgnore, file, line);
	}

	this(Location loc, string message, string file = __FILE__, size_t line = __LINE__)
	{
		super(loc, message, null, false, file, line);
	}

	this(Location loc, string message, CompilerError more, string file = __FILE__, size_t line = __LINE__)
	{
		super(loc, message, more, false, file, line);
	}

	this(Location loc, string message, CompilerError more, bool neverIgnore, string file = __FILE__, size_t line = __LINE__)
	{
		super(loc, message, more, neverIgnore, file, line);
	}
}

class MissingSemicolonError : CompilerError
{
public:
	this(Location loc, string type, string file = __FILE__, size_t line = __LINE__)
	{
		loc.column += loc.length;
		loc.length = 1;

		super(loc, format("missing ';' after %s.", type), file, line);

		fixHint = ";";
	}
}

class PairMismatchError : CompilerError
{
public:
	this(Location pairStart, Location loc, string type, string token, string file = __FILE__, size_t line = __LINE__)
	{
		loc.column += loc.length;
		loc.length = token.length;

		super(loc, format("expected '%s' to close %s.", token, type), file, line);

		fixHint = token;

		more = new CompilerError(pairStart, format("%s started here.", type));
	}
}

// For catching purposes
class ArgumentMismatchError : CompilerError
{
public:
	enum ptrdiff_t unspecified = -1;
	ptrdiff_t argNumber = unspecified;

public:
	this(Location loc, string message, string file = __FILE__, size_t line = __LINE__)
	{
		super(loc, message, file, line);
	}

	this(Location loc, string message, ptrdiff_t argNumber, string file = __FILE__, size_t line = __LINE__)
	{
		this.argNumber = argNumber;
		super(loc, message, file, line);
	}
}

/**
 * Aka Internal Compiler Error, aka ICE, aka CompilerPanic.
 */
class CompilerPanic : CompilerException
{
public:
	this(string message, string file = __FILE__, size_t line = __LINE__)
	{
		super(message, null, true, file, line);
	}

	this(Location loc, string message, string file = __FILE__, size_t line = __LINE__)
	{
		super(loc, message, null, true, file, line);
	}

override:
	string errorFormat()
	{
		return "panic: %s";
	}

	string locationFormat()
	{
		return "%s: panic: %s";
	}
}

void errorMessageOnly(Location loc, string message, string file = __FILE__, size_t line = __LINE__)
{
	writefln(format("%s: error: %s", loc.toString(), message));
}
