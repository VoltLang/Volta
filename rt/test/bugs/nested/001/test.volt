//T has-passed:no
module test;


struct Foo
{
	a, b: i32;
}

fn funcA(f: const Foo) i32
{
	// Both of these bugs are triggered by the nested function.
	// Probably due to the field on the nested variable is const.
	fn nest() i32 {
		return f.a;
	}
	return nest();
}

fn funcB(in f: Foo) i32
{
	// See above.
	fn nest() i32 {
		return f.b;
	}
	return nest();
}

fn main(args: string[]) i32
{
	f: Foo;
	f.a = 4;
	f.b = 5;
	return (funcA(f) + funcB(f)) == 9 ? 0 : 1;
}
