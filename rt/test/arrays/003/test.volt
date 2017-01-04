// Test slicing.
module test;


fn main() i32
{
	str: char[] = new char[](6);
	otherStr: char[] = str[0 .. 4];

	return (cast(int)otherStr.length == 4) ? 0 : 1;
}
