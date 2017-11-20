module test;

interface IFace
{
	fn foo(ref i: i32, j: i16);
}

fn bar(i: IFace)
{
	x := 32;
	i.foo(ref x, 12);
}

fn main(args: string[]) i32
{
	return 0;
}
