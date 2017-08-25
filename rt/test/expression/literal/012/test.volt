//T macro:expect-failure
module test;

fn main() i32
{
	foo := "foo";
	bar := foo "bar";
	return 0;
}
