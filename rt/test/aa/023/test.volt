//T compiles:yes
//T retval:2
module test;

fn main() i32
{
	a: i32[] = [1, 2, 3];
	aa: i32[][string];
	aa["hello"] = a;
	return aa["hello"][1];
}
