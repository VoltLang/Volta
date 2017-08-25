//T macro:expect-failure
//T check:expected integral or bool value
module test;

fn main() i32
{
	de := !"hello";
	return 0;
}
