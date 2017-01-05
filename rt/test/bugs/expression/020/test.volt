module test;

fn main() i32
{
	aa: i32[string];
	aa["foo"] = 32;
	if (p := "foo" in aa) {
		return *p - 32;
	} else {
		return 2;
	}
}

