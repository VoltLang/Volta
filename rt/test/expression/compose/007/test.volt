//T macro:expect-failure
//T check:non constant expression
module test;

fn main(args: string[]) i32
{
	str := "${args.length}";
	return 0;
}
