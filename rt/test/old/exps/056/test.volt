//T compiles:yes
//T retval:3
module test;

int main()
{
	auto a = [1, 2, 3];
	auto b = new a[0 .. 2];
	a[0] = 2;
	return b[0] + cast(int)b.length;
}
