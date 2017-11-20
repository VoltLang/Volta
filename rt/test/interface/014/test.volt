module test;

interface IFace
{
	fn foo(ref i: i32, j: i16);
}

global var: i32;

class Implement : IFace
{
	override fn foo(ref i: i32, j: i16)
	{
		var = cast(i32)j + i;
	}
}

fn bar(i: IFace)
{
	x := 32;
	i.foo(ref x, 12);
}

fn main(args: string[]) i32
{
	i := new Implement();
	bar(i);
	return var - 44;
}
