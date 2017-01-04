//T default:no
//T macro:importfail
// Non-public import rebind.
module test;

import m8;


fn main() i32
{
	return ctx.exportedVar;
}
