//T requires:exceptions
// Simple test of throw, scope (failure).
module test;

import core.exception;

global i: i32;

fn foo()
{
	throw new Exception("error");
}

fn bar()
{
	scope (failure) i = 32;
	foo();
}

fn main() i32
{
	try {
		bar();
	} catch (e: Exception) {
	}
	return i == 32 ? 0 : 1;
}

