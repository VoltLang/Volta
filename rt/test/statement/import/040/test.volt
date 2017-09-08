//T macro:expect-failure
module test;

static import core.object;

fn core() i32
{
	return 0;
}

fn main() i32
{
	return core();
}
