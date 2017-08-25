//T macro:expect-failure
// Invalid key type accessing aa.
module test;

fn main() i32
{
	aa: i32[i32];
	return aa["volt"];
}

