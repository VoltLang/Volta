module test;


fn main() i32
{
	charVar: char;

	static is (typeof(charVar + charVar) == i32);

	return 0;
}

