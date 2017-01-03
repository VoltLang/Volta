module test;


struct Foo
{
	i: i32;
}

fn main() i32
{
	arr: i32[];
	foreach (e; arr) {
		fn nest()
		{
			foreach (e; arr) {
			}
			f: Foo = { e };
		}
	}
	return 0;
}
