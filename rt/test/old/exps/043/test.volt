//T compiles:yes
//T retval:12
module test;

int main()
{
	auto a = [1, 6, 7] ~ [2, 4];
	return a[1] + a[3] + a[4];
}

