//T default:no
//T macro:expect-failure
module test;

fn f01(b: bool)
{
	return;
	assert(false);
}

fn main() i32
{
	f01(false);
	return 0;
}
