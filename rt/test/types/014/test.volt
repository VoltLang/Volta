//T compiles:yes
//T retval:3
// Ensure that immutable can become const with no mutable indirection.
module test;


void foo(const(char)[])
{
	return;
}

int main()
{
	immutable(char)[] str;
	foo(str);
	return 3;
}
