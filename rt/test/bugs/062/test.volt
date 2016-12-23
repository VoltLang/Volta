//T compiles:yes
//T retval:2
module test;

int main()
{
	auto a = [1, 2, 3];
	a[0] = 2;
	return a[0];
}
