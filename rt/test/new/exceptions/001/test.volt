//T requires:exceptions
// A simple test of throw, try, catch, Exception.
module test;

import core.exception;

fn main() i32
{
	try {
		throw new Exception("error");
	} catch (e: Exception) {
		return 0;
	}
	return 1;
}

