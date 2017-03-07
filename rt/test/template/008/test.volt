module test;

struct Struct!(T)
{
	a: T;
}

struct StringStruct = mixin Struct!string;
struct IntStruct = mixin Struct!i32[];

fn main(args: string[]) i32
{
	_is: StringStruct;
	_is.a = "hello";
	_is2: IntStruct;
	_is2.a = [1, 2, 3];
	return cast(i32)_is.a.length - (2 + cast(i32)_is2.a.length);
}
