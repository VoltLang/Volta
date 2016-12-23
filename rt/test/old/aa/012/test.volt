//T compiles:yes
//T retval:7
module test;

int main()
{
	int[string] foo;
	foo["aaa"] = 1;
	foo["bbbb"] = 2;

	auto f = foo.keys;

	return cast(int)(f[0].length + f[1].length);
}
