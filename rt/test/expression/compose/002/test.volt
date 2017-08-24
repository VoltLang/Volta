//T default:no
//T macro:expect-failure
//T check:cannot use type
module test;

fn main() i32
{
	str := new "${main}";
	return 0;
}
