// Test AA initialisers.
module test;

fn main() i32
{
	aa := [3:42];
	return aa[3] == 42 ? 0 : 1;
}
