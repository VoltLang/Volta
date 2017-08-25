//T macro:expect-failure
//T check:implicitly convert
// Arrays of arrays gets accepted.
module bugs;


fn main() i32
{
	return func("bug here");
}

fn func(f: string[]) i32
{
	return 0;
}
