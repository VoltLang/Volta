// Impicit cast to const pointer doesn't work.
module test;


fn func(ptr: const(char)*)
{
	return;
}

fn main() i32
{
	ptr: char*;
	func(ptr);

	return 0;
}
