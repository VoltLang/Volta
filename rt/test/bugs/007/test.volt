// Invalid escape.
module test;


fn main() i32
{
	arr := new char[](1);
	arr[0] = '\n';
	arr[0] = '\0';

	c: char = '\0';

	return 0;
}
