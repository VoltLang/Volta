//T default:no
//T macro:expect-failure
//T check:all arguments must be labelled
module test;

@label fn sub(a: i32, b: i32) i32 {
	return a - b;
}

fn main() i32
{
	return sub(1, a:3);
}
