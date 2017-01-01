module test;

fn multIntegers(i: i32, j: i32) i32
{
	return i * j;
}

fn main() i32
{
	fp: fn (i32, i32) i32 = multIntegers;
	return fp(3, 2) - 6;
}
