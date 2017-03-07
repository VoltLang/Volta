module test;

struct Struct!(T)
{
	a: T;

	global fn foo() i32
	{
		return 0;
	}
}

struct StringStruct = mixin Struct!string;

fn main(args: string[]) i32
{
	_is: StringStruct;
	_is.a = "hello";
	return StringStruct.foo();
}
