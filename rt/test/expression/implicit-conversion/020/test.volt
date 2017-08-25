//T macro:expect-failure
//T check:cannot implicitly convert
module test;

fn main() i32
{
	aa: i32[string];
	s := "hello" in aa;
	if (s !is null) {
		return 1;
	}
	s["hello"] = 3;
	return 0;
}
