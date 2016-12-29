module test;

enum StringEnum = "enum1";

fn main() i32
{
	str := "enum1";
	switch (str) {
	case StringEnum: return 0;
	default:
	}
	return 12;
}
