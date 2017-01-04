// Overload doesn't work on arrays of arrays.
module bugs;


fn main() i32
{
	return func("bug here");
}

fn func(f: string) i32
{
	return 0;
}

fn func(f: string[]) i32
{
	return 3;
}
