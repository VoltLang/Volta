module test;

interface IFace
{
	fn foo() i32;
}

class A : IFace
{
	override fn foo() i32
	{
		return 1;
	}
}

class B : A, IFace
{
	override fn foo() i32
	{
		return 2;
	}
}

fn main() i32
{
	ifc: IFace = new B();
	return ifc.foo() - 2;
}
