module test;

fn main() i32
{
	fn dgt() {}
	x: i32 = 5;
	getoptImpl(ref x, dgt);
	return x - 5;
}

fn getoptImpl(ref args: i32, dgt: scope dg())
{
}

fn getoptImpl(ref args: i32, dgt: scope dg(string))
{
	args = 34;
}

