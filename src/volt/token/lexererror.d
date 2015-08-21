// Copyright © 2015, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.token.lexererror;

import watt.text.format : format;

import volt.exceptions;
import volt.token.location : Location;

enum LexStatus {
	Succeeded = 1,
	Failed = 0
}
alias Succeeded = LexStatus.Succeeded;
alias Failed = LexStatus.Failed;


/// Describes a lexer failure.
abstract class LexerError
{
public:
	enum Kind
	{
		/// No error.
		Ok = 0,
		/// Tried to lex something, but it failed.
		LexFailed,
		/// Expected something that wasn't there.
		Expected,
		/// Didn't expect something that we got.
		Unexpected,
		/// Tried to use an unsupported feature.
		Unsupported,
		/// Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah! (Compiler Error)
		Panic
	}

public:
	Kind kind;
	Location location;
	dchar currentChar;

public:
	this(Kind kind, Location loc, dchar currentChar)
	{
		this.kind = kind;
		this.location = loc;
		this.currentChar = currentChar;
	}

public:
	abstract string errorMessage();
}


/// An error with a string.
class LexerStringError : LexerError
{
public:
	string str;

public:
	this(Kind kind, Location loc, dchar currentChar, string str)
	{
		super(kind, loc, currentChar);
		this.str = str;
	}

public:
	override string errorMessage()
	{
		final switch (kind) with (LexerError.Kind) {
		case Expected:
			return format("expected '%s'.", str);
		case Unexpected:
			return format("unexpected '%s'.", str);
		case LexFailed:
			return format("failed parsing a '%s'.", str);
		case Unsupported:
			return format("'%s' is an unsupported feature.", str);
		case Ok:
		case Panic:
			break;
		}
		assert(false);
	}
}

class LexerPanicError : LexerError
{
public:
	CompilerException panicException;

public:
	this(Location loc, dchar currentChar, CompilerException panicException)
	{
		super(LexerError.Kind.Panic, loc, currentChar);
		panicException = panicException;
	}

public:
	override string errorMessage()
	{
		throw panicException;
	}
}

