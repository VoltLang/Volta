//T default:no
//T macro:importfail
module test;

import ctx = m1 : exportedVar1 = exportedVar;


fn main() i32
{
	return ctx.otherVar;
}
