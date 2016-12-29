//T default:no
//T macro:expect-failure
module test;

fn main() i32
{
	() @trusted {} ();
	return 0;
}
