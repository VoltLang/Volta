//T compiles:yes
//T retval:12
module test;

enum StringEnum = "enum1";


fn main() i32
{
	str := "enum1";
	switch (str) {
	case StringEnum: return 12;
	default:
	}
	return 0;
}
