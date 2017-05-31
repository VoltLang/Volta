//T default:no
//T macro:expect-failure
//T check:used before declaration
module test;

fn main(args: string[]) i32
{
	if (args.length > 0) {
		x = 32;
	}
	x: i32;
	return x;
}
