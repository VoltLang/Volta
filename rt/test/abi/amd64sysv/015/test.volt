//T requires:sysvamd64
module test;

extern (C) fn func(a: string, b: string) i32
{
	return cast(i32)a.length + cast(i32)b.length;
}

fn main() i32
{
	return func("ab", "cde") - 5;
}
