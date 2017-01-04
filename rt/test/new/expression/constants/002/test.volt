module test;

fn main(args: string[]) i32
{
	return __LOCATION__[$-11 .. $] == "test.volt:5" ? 0 : 15;
}
