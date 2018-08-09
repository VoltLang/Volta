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

fn throwAnUnrelatedFunc()
{
	throw new AnUnrelatedException();
}

fn catchFunc() i32
{
	val := 0;

	try {
		throwFunc();
	} catch (oe: OurException) {
		oe.val++;
		val += oe.val;
		try {
			throwFunc();
		} catch (oe2: OurException) {
			oe2.val++;
			val += oe2.val * 2;
			try {
				try {
					throwFunc();
					try {
						throwAnUnrelatedFunc();
					} catch (oe5: OurException) {
						val = 6000;
					}
				} catch (oe4: OurException) {
					oe4.val++;
					val += oe4.val * 4;
					throw oe4;
				}
			} catch (oe3: OurException) {
				oe3.val++;
				if (oe3.val != 2) {
					val = 7000;
				}
				val += oe3.val * 3;
			}
			if (oe2.val != 1) {
				val = 9000;
			}
		}
		if (oe.val != 1) {
			val = 8000;
		}
	}

	try {
		try {
			throwFunc();
		} catch (oe: OurException) {
			try {
				throwAnUnrelatedFunc();
			} catch (aue: AnUnrelatedException) {
				try {
					throwFunc();
				} catch (oe2: OurException) {
					return val - 13;
				}
			}
		}
	} catch (oe: OurException) {
		return 13;
	}

	return 14;
}
