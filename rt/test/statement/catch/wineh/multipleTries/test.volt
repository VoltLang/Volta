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
	e := new OurException(0);
	throw e;
}

fn catchFunc() i32
{
	val := 0;
	try {
		throwFunc();
	} catch (oe: OurException) {
		val += 2;
	}

	if (val == 2) {
		try {
			throwFunc();
		} catch (oe: OurException) {
			val += 3;
		}
	}

	try {
		throwFunc();
	} catch (oe: OurException) {
		val++;
	}

	return val - 6;
}
