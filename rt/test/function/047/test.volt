// A small exercise of ref.
module test;


fn addOne(ref i: i32)
{
	base: i32 = i;
	i = base + 1;
}

fn main() i32
{
	i: i32 = 29;
	addOne(ref i);
	return i - 30;
}
