// Basic AA test.
module test;

fn main() i32
{
	aa: i32[string];
	key := "volt";
	aa[key] = 42;
	return aa["volt"] == 42 ? 0 : 1;
}
