//T default:no
//T macro:expect-failure
//T check:attempted to assign to
module test;

struct S
{
	x: i32 = 3;
}

fn main() i32
{
	return 0;
}

