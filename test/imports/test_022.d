//T compiles:yes
//T retval:32
//T has-passed:no
// Try to use defaultsymbols even more.
module test_022;

int func(string str)
{
	return cast(int)str[5];
}

int main()
{
	string str = "Hello World";

	return func(str);
}
