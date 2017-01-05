module test;

fn b(ref val: i32)
{
	fn dgt(param: i32) { val = param; }
	val = 7;
}

fn main() i32
{
	val: i32;
	b(ref val);
	return val - 7;
}

