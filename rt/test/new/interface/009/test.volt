module test;

interface Foo
{
	fn func() i32;
}

class Bar : Foo
{
	override fn func() i32 { return 0; }
}

fn main() i32
{
	obj := new Bar();
	f := cast(Foo)obj;
	return f.func();
}

