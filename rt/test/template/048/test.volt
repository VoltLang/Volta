module test;

struct Foo!(K, V)
{
	static assert(false, "banana");
}

fn main() i32
{
	return 0;
}
