module test;


struct Foo
{
	a: i32;
}

fn func(in ref f: Foo) i32
{
	// ^ .../003/test.volt:10:12: error: expected primitive type.
	return f.a;
}

global fptr: fn(in ref Foo) i32;

fn main(args: string[]) i32
{
	f: Foo;
	f.a = 4;
	return func(ref f) == 4 ? 0 : 1;
}
