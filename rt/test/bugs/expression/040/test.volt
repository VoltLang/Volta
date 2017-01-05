module test;


class Foo {
	enum u64 err = 4;
}

enum u64 works = 4;

fn func(u32) {}

fn main() i32
{
	// This is okay.
	func(works);

	// But not this.
	func(Foo.err);
	return 0;
}
