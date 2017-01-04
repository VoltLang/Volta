// AA test.
module test;

fn main() i32
{
	foo: i32[string];
	foo["aaa"] = 1;
	foo["bbbb"] = 2;

	f := foo.keys;

	return cast(i32)(f[0].length + f[1].length) == 7 ? 0 : 1;
}
