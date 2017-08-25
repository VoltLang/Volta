//T macro:expect-failure
//T check:balloon
module test;

static assert(false, "balloon");

fn main() i32
{
	return 0;
}
