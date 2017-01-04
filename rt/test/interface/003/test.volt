module test;

interface A
{
	fn getNumber() i32;
}

interface B
{
	fn getThree() i32;
}

interface X
{
	fn getOne() i32;
}

class C : A
{
	override fn getNumber() i32
	{
		return 1;
	}
}

class D : C, X, B
{
	override fn getNumber() i32
	{
		return 2;
	}

	override fn getThree() i32
	{
		return 3;
	}

	override fn getOne() i32
	{
		return 1;
	}
}

int pointlessMiddleman(a: A, b: B, x: X)
{
	return a.getNumber() + b.getThree() + x.getOne();
}

fn main() i32
{
	d := new D();
	return (pointlessMiddleman(d, d, d) == 6) ? 0 : 1;
}

