//T requires:exceptions
// A simple test of throw, nested try, catch, Exception.
module test;

import core.exception;

fn main() i32
{
	a: i32 = 0;
	try {
		try {
			try {
				throw new Exception("error");
			} catch (e: Exception) {
				a = 1;
			}
		} catch (e: Exception) {
			a = 2;
		}
	} catch (e: Exception) {
		a = 3;
	}
	return a == 1 ? 0 : 1;
}

