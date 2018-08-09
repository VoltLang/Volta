//T requires:exceptions
// Simple test of finally.
module test;

import core = core.exception;

global gVar: i32;

fn alpha() i32
{
	val := 0;
	try {
		val = 3;
	} finally {
		val += 3;
	}
	return val;
}

fn beta()
{
	try {
		eagle();
	} finally {
		gVar += 7;
	}
	gVar -= 7;
}

fn charlie() i32
{
	val := 0;
	try {
		eagle();
		val = 4;
	} catch (e: core.Exception) {
		val = 5;
	} finally {
		val += 3;
	}
	return val;
}

fn eagle()
{
	throw new core.Exception("oh no, a test string");
}

fn main() i32
{
	try {
		beta();
	} catch (t: core.Throwable) {
	}
	return alpha() + gVar + charlie() - 21;
}
