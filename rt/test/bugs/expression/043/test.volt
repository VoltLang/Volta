module test;


fn over(foo: i32[]) i32
{
	return foo[0];
}

fn func(ptr: i32*, len: size_t) i32
{
	return 42;
}

alias func = over;

fn main() i32
{
	arr: i32[1];
	arr[0] = 10;

	return func(arr) - 10;
}
