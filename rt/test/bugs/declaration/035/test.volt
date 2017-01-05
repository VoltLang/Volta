module test;

enum Foo : u32 { one = 1, two, three }

fn main() i32
{
	foo: u32 = Foo.three;
	return cast(i32) (Foo.two + foo) - 5;
}
