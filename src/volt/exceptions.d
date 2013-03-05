// Copyright © 2010, Bernard Helyer.  All rights reserved.
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.exceptions;

import std.stdio : writefln;
import std.string : format;

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
	this(string message, CompilerError more, bool neverIgnore)
	{
		this.more = more;
		this.neverIgnore = neverIgnore;
		super(format(errorFormat(), message));
	}

	this(Location loc, string message, CompilerError more, bool neverIgnore)
	{
		this.more = more;
		this.location = loc;
		this.hasLocation = true;
		this.neverIgnore = neverIgnore;
		super(format(locationFormat(), loc.toString(), message));
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
	this(string message, CompilerError more = null)
	{
		super(message, more, false);
	}

	this(Location loc, string message, bool neverIgnore)
	{
		super(loc, message, null, neverIgnore);
	}

	this(Location loc, string message, CompilerError more = null)
	{
		super(loc, message, more, false);
	}
}

class MissingSemicolonError : CompilerError
{
public:
	this(Location loc, string type)
	{
		loc.column += loc.length;
		loc.length = 1;

		super(loc, format("missing ';' after %s.", type));

		fixHint = ";";
	}
}

class PairMismatchError : CompilerError
{
public:
	this(Location pairStart, Location loc, string type, string token)
	{
		loc.column += loc.length;
		loc.length = token.length;

		super(loc, format("expected '%s' to close %s.", token, type));

		fixHint = token;

		more = new CompilerError(pairStart, format("%s started here.", type));
	}
}

// For catching purposes
class ArgumentMismatchError : CompilerError
{
public:
	const ptrdiff_t unspecified = -1;
	ptrdiff_t argNumber = unspecified;

public:
	this(Location loc, string message)
	{
		super(loc, message);
	}

	this(Location loc, string message, ptrdiff_t argNumber)
	{
		this.argNumber = argNumber;
		super(loc, message);
	}
}

/**
 * Aka Internal Compiler Error, aka ICE, aka CompilerPanic.
 */
class CompilerPanic : CompilerException
{
	static CompilerPanic opCall(string message,
	                            string file = __FILE__,
	                            int line = __LINE__)
	{
		auto c = new CompilerPanic(message);
		c.file = file;
		c.line = line;
		return c;
	}

	static CompilerPanic opCall(Location loc,
	                            string message,
	                            string file = __FILE__,
	                            int line = __LINE__)
	{
		auto c = new CompilerPanic(loc, message);
		c.file = file;
		c.line = line;
		return c;
	}

protected:
	this(string message)
	{
		super(message, null, true);
	}

	this(Location loc, string message)
	{
		super(loc, message, null, true);
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

void errorMessageOnly(Location loc, string message)
{
	writefln(format("%s: error: %s", loc.toString(), message));
}

void warning(Location loc, string message)
{
	writefln(format("%s: warning: %s", loc.toString(), message));
}
