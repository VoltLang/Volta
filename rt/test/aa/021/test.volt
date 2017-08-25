//T macro:expect-failure
module test;

fn main() i32
{
	obj := new object.Object();
	aa: i32[object.Object];
	aa[obj] = 12;
	return aa[obj];
}
