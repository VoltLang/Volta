//T compiles:no
//T error-message:11:9: error: enum 'A' does not define 'C'.
module test;

enum A {
	B
}

fn main() i32
{
	return A.C;
}
