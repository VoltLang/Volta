module main;

import core.exception : Throwable, Exception;

class OurException : Exception
{
	val: i32;

	this(val: i32)
	{
		this.val = val;
		super(new "The supplied error code was ${val}.");
	}
}

class AnUnrelatedException : Exception
{
	this()
	{
		super("This code will never be run, and yet I'm writing this message.");
	}
}

class AnUnrelatedException2 : Exception
{
	this()
	{
		super("This code will never be run, and yet I'm writing this message.");
	}
}

fn main() i32
{
	return catchFunc();
}

extern (C):

fn throwFunc()
{
	e := new OurException(6);
	throw e;
}

fn catchFunc() i32
{
	val: i32;
	try {
		throwFunc();
		val = 12;
	} catch (aue: AnUnrelatedException) {
		val = 21;
	} catch (e: AnUnrelatedException2) {
		val = 71;
	} catch (oe: OurException) {
		val = oe.val;
	}
	return val - 6;
}
