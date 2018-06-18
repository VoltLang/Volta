//T macro:expect-failure
module main;

fn main() i32
{
	a := [1, 2, 3];
	foreach (a) {
	}
	return 0;
}