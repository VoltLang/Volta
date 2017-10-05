//T macro:expect-failure
//T check:cannot implicitly convert
module test;

fn BadFunc()
{
	return true;
}

fn main() i32
{
	return 0;
}
