module test;

fn x() i32
{
	a: i32;
	version (!none) {
		a = 0;
	}
	version ((all && !none) || none) {
		a = a * 2;
	}
	version (!all) {
		a = a + 2;
	}
	version (none || all) {
		a = a + 1;
	}
	return a - 1;
}

fn main() i32
{
	return x();
}
