// AA as lvalue.
module test;

fn main() i32
{
	aa: i32[string];
	return aa["volt"] = 0;
}

