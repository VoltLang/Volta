// Directly indexing AA expressions.
module test;

fn main() i32
{
	a: i32[] = [1, 2, 3];
	aa: i32[][string];
	aa["hello"] = a;
	return aa["hello"][1] == 2 ? 0 : 1;
}
