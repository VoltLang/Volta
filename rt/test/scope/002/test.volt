//T requires:exceptions
// Simple test of throw, scope (success).
module test;

import core.exception;

global i: i32;

fn foo()
{
}

fn bar()
{
	scope (success) i = 16;
	scope (failure) i = 32;
	foo();
}

fn main() i32
{
	bar();
	return i == 16 ? 0 : 1;
}

