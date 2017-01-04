//T default:no
//T macro:expect-failure
module test;

fn main() i32
{
	static assert(false, "if you can read this, I'm working!");
	return 0;
}
