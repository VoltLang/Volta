module test;

struct Structure {
	fn foo() {
	}
}

global str: Structure;

fn main() i32
{
	fn vdg() { str.foo(); }
	return 0;
}

