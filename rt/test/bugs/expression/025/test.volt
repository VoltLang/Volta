module test;

fn addOne(ref i: i32)
{
	i += 1;
}

fn set(out i: i32, N: i32)
{
	i = N;
}

fn main() i32
{
	x: i32;
	x.set(41);
	x.addOne();
	return x - 42;
}

