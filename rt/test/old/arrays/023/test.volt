//T compiles:yes
//T retval:6
module test;

int main()
{
	auto a = [1, 2, 3];
	auto b = new a[..];
	a[1] = 30;
	return b[0] + b[1] + b[2];
}

