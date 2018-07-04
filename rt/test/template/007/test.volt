//T macro:expect-failure
//T check:template definition is of type 'union'
module test;

union Struct!(T)
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
