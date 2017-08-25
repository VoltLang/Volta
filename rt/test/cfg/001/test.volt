//T macro:expect-failure
module test;

fn main(args: string[]) i32
{
	x: i32;
	if (args.length >= 1) {
		return 0;
		x++;
	}
	return x;
}
