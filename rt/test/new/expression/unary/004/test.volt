module test;

class A
{
	fn x() i32 { return 6; }
}

class C : A
{
}

class B : A
{
}

class D : B
{
}

fn main(args: string[]) i32
{
	c := new C();
	d := new D();
	a: A = args.length > 1 ? c : d;
	return a.x() - 6;
}
