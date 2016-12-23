//T compiles:no
module test;

class A
{
}

fn main() i32
{
	a := new A();
	de := +a;
	return 0;
}
