// AA get method, remove.
module test;

fn main() i32
{
	aa: i32[string];
	aa["hello"] = 35;
	aa.remove("hello");
	return aa.get("hello", 31) == 31 ? 0 : 1;
}
