//T compiles:yes
//T retval:1
module test;

struct Foo { a: i32; global f: const(Foo) = { 1 }; }

fn main() i32
{
	return Foo.f.a;
}