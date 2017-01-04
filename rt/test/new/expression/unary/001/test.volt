module test;

fn main() i32
{
	val21: i32 = 21;
	val20: i32 = --val21;
	val21 = ++val20;

	return val21 + val20 - 42;
}
