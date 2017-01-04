// Ensure that immutable can become const with no mutable indirection.
module test;


fn foo(const(char)[])
{
}

int main()
{
	str: immutable(char)[];
	foo(str);
	return 0;
}
