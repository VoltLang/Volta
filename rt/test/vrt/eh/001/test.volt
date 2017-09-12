module test;

import core.c.stdlib;

import core.exception;
import core.rt.eh;


class ExpectedException : Exception
{
	this(location: string = __LOCATION__)
	{
		super("expected", location);
	}
}

fn onThrow(t: Throwable, location: string)
{
	if (e := cast(ExpectedException)t) {
		exit(0);
	} else {
		exit(1);
	}
}

fn main() i32
{
	vrt_eh_set_callback(onThrow);
	throw new ExpectedException();
}
