//T compiles:yes
//T retval:42
// Impicit cast to const pointer doesn't work.
module test_008;

void func(const(char)* ptr)
{
	return;
}

int main()
{
	char* ptr;
	func(ptr);

	return 42;
}
