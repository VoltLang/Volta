//T macro:expect-failure
//T check:expected
module main;

fn main() i32
{
	x := 1;
	str := new "${x}${x";
	return 0;
}
