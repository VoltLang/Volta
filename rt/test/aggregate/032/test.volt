//T default:no
//T macro:expect-failure
//T check:const or immutable non local/global field
module test;

struct S
{
	x: const(i32);
}

fn main() i32
{
	return 1;
}

