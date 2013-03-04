//T compiles:yes
//T retval:8
// Passing MI to scope type argument.
module test_024;

int func(scope int* ptr)
{
	return *ptr;
}

int main()
{
	int i = 8;
	int* ip = &i;
	return func(ip);
}
