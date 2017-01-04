module test;


fn main() i32
{
	foo: immutable i32;

	i1: typeof(foo + 4);
	i2: typeof(4 + foo);

	i1 = 20;
	i2 = 22;

	return i1 + i2 - 42;
}
