// Local/global variables in structs.
module test;


struct Test
{
	val: i32;
	local localVal: i32;
}

fn main() i32
{
	Test.localVal = 42;
	return Test.localVal - 42;
}
