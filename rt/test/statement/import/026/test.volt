//T macro:importfail
// Non-public import rebind.
module test;

import m9;


fn main() i32
{
	return exportedVar1;
}
