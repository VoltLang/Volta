// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.exception;


class Throwable
{
	msg: string;

	// This is updated each time the exception is thrown.
	throwLocation: string;

	// This is manually supplied.
	location: string;

	this(msg: string, location: string = __LOCATION__)
	{
		this.msg = msg;
		this.location = location;
	}
}

class Exception : Throwable
{
	this(msg: string, location: string = __LOCATION__)
	{
		super(msg, location);
	}
}

class Error : Throwable
{
	this(msg: string, location: string = __LOCATION__)
	{
		super(msg, location);
	}
}

class AssertError : Error
{
	this(msg: string, location: string = __LOCATION__)
	{
		super(msg, location);
	}
}

class MalformedUTF8Exception : Exception
{
	this(msg: string = "malformed UTF-8 stream",
	     location: string = __LOCATION__)
	{
		super(msg, location);
	}
}

// Thrown if Key does not exist in AA
class KeyNotFoundException : Exception
{
	this(msg: string)
	{
		super(msg);
	}
}
