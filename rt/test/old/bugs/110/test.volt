//T compiles:yes
//T retval:42
module test;

int main()
{
	void got() {}
	auto y = got;

	return 42;
}
