module test;

class Foo
{
	fn func1(f: const(char)[]) i32
	{
		return dummy(f);
	}

	fn func2(f: const(char)*) i32
	{
		return dummy(f);
	}
}

fn dummy(f: const(char)[]) i32
{
	return 20;
}

fn dummy(f: const(char)*) i32
{
	return 22;
}

fn main() i32
{
	f := new Foo();
	return f.func1(null) + f.func2(null) - 42;
}
