//T default:no
//T macro:expect-failure
//T check:expected integral value
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
