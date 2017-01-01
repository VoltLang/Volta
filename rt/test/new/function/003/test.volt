module test;

fn func(i: i32, x: i32)
{
	fn nest() {
	}
	nest();
}

fn func()
{
	fn nest() {
	}
	nest();
}

fn main() i32
{
	func();
	func(1, 2);
	return 0;
}

