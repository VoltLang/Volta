//T compiles:no
module test;

fn foo()
{
}

fn main() i32
{
	bar: void;
	bar = foo();
	return 0;
}
