// Tests passing ref vars around to ref functions and non-ref functions.
module test;


fn deepest(ref i: i32)
{
	i = 19;
}

fn deep(ref i: i32)
{
	deepest(ref i);
	i = timesTwo(i);
}

fn timesTwo(i: i32) i32
{
	return i * 2;
}

fn main() i32
{
	i: i32;
	deep(ref i);
	return i - 38;
}
