//T macro:expect-failure
//T check:8:6: error: cannot
module test;

fn main() i32
{
	a := 32;
	b := new "${\"hello\" ~ a}";
	return a - 32;
}

