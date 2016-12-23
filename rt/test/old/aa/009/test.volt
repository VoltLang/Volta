//T compiles:yes
//T retval:42
// AA initializer.
module test;


int main()
{
	int result = 42;
	auto aa = [3:result];
	return aa[3];
}
