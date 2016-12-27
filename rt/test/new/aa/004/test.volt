// Basic AA test, forwarding ops to value.
module test;

fn main() i32
{
	aa: i32[string];
	key := "volt";
	aa["volt"] = 20;
	aa[key] += 1;
	aa["volt"] *= 2;
	return aa[key] == 42 ? 0 : 1;
}
