//T macro:res-failure
//T check:string import path with '..'.

fn main() i32
{
	str := import("../044/test.volt");
	return 0;
}
