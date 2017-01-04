//T default:no
//T macro:expect-failure
//T check:expected non-void pointer
module test;

fn main() i32
{
	p: void*;
	c := *p;
	return 0;
}

