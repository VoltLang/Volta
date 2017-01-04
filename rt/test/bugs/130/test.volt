module test;

extern(C) fn printf(const(char)*, ...) i32;


fn main() i32
{
	printf("%p\n", null);
	return 0;
}
