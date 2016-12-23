//T compiles:yes
//T retval:2
module test;

int main()
{
	a := [1, 2, 3];
	b := new a[0 .. $-1];
	return b[$-1];
}
