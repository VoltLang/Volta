// Passing MI to scope type argument.
module test;


fn func(ptr: scope i32*) i32
{
	return *ptr;
}

fn main() i32
{
	i: i32 = 8;
	ip: i32* = &i;
	return func(ip) - 8;
}
