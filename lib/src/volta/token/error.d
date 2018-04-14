/*#D*/
// Copyright 2015, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
module volta.token.error;

import watt.text.format : format;

import volta.ir.location : Location;

enum LexStatus {
	NotPresent = 2,
	Succeeded = 1,
	Failed = 0
}
alias NotPresent = LexStatus.NotPresent;
alias Succeeded = LexStatus.Succeeded;
alias Failed = LexStatus.Failed;


//! Describes a lexer failure.
abstract class LexerError
{
public:
	enum Kind
	{
		//! No error.
		Ok = 0,
		//! Tried to lex something, but it failed.
		LexFailed,
		//! Expected something that wasn't there.
		Expected,
		//! Didn't expect something that we got.
		Unexpected,
		//! Tried to use an unsupported feature.
		Unsupported,
		//! Display the given string.
		String,
		//! Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaah! (Compiler Error)
		Panic
	}

public:
	Kind kind;
	Location loc;
	dchar currentChar;

public:
	this(Kind kind, Location loc, dchar currentChar)
	{
		this.kind = kind;
		this.loc = loc;
		this.currentChar = currentChar;
	}

public:
	abstract string errorMessage();
}


//! An error with a string.
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
		case String:
			return str;
		case Ok:
		case Panic:
			break;
		}
		assert(false);
	}
}
