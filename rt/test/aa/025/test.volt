//T macro:expect-failure
module test;

struct Struct
{
	a: i32[];
}

fn main(args: string[]) i32
{
	aa: i32[Struct];
	return 0;
}
