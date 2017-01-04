module test;

fn foo(i: i32) i32
{
	return i + 1;
}

fn bar(i: i32) i32
{
	return i + 2;
}

fn baz(a: i32, b: i32) i32
{
	return b;
}

fn main() i32
{
	gah: i32 = 2;
	return gah.foo() + gah.bar() + gah.baz(3) - 10;
}

