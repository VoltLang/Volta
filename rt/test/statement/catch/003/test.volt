//T requires:exceptions
module test;

import core.exception;


fn main() i32
{
	try {
		throw new Exception("hello");
	} catch (Exception e) {
		return 0;
	}
}
