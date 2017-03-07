module test;

struct Struct!(T)
{
	a: T;

	fn foo() i32
	{
		return cast(i32)a.length;
	}
}

struct StringStruct = mixin Struct!string;

fn main(args: string[]) i32
{
	_is: StringStruct;
	_is.a = "hello";
	return _is.foo() - 5;
}
