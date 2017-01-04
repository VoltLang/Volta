module test;

class Base {}
class Sub : Base {}

fn foo(i32) {}
fn foo(Base) {}

fn func(out sub: Sub)
{
	foo(sub);
}

fn main() i32
{
	return 0;
}
