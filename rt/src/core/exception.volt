// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.exception;


class Throwable
{
	msg: string;

	// This is updated each time the exception is thrown.
	throwLocation: string;

	// This is manually supplied.
	loc: string;

	this(string msg, string location = __LOCATION__)
	{
		this.msg = msg;
		this.loc = location;
	}
}

class Exception : Throwable
{
	this(string msg, string location = __LOCATION__)
	{
		super(msg, location);
	}
}

class Error : Throwable
{
	this(string msg, string location = __LOCATION__)
	{
		super(msg, location);
	}
}

class AssertError : Error
{
	this(string msg, string location = __LOCATION__)
	{
		super(msg, location);
	}
}

class MalformedUTF8Exception : Exception
{
	this(string msg = "malformed UTF-8 stream",
	     string location = __LOCATION__)
	{
		super(msg, location);
	}
}

// Thrown if Key does not exist in AA
class KeyNotFoundException : Exception
{
	this(string msg)
	{
		super(msg);
	}
}
