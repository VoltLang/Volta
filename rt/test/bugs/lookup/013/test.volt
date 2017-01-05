module test;

fn getoptImpl(dgt: scope dg()) i32
{
	return 1;
}

fn getoptImpl(dgt: scope dg(string)) i32
{
	return 2;
}

fn main() i32
{
	fn dgt() {}
	return getoptImpl(dgt) - 1;
}

