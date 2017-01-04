module test;


fn foo(base: i32, ...) i32
{
	return base + cast(int) _typeids[0].size + cast(int) _typeids[1].size;
}

fn main() i32
{
	i: i32;
	s: i16;
	return foo(36, i, s) - 42;
}
