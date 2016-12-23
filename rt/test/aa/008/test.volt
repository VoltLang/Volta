//T compiles:yes
//T retval:42
// AA initializer.
module test;


int main()
{
	auto aa = [3:42];
	return aa[3];
}
