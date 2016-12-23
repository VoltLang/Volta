//T compiles:yes
//T retval:3
module test;

int main()
{
	a := [1, 2, 3];
	b := a[..];
	return b[$-1];
}
