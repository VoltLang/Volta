//T compiles:yes
//T retval:4
// Multiple Variable declarations in one.
module test_018;

alias Sint32 = int;


int main()
{
	int x, y;
	Sint32 z, w;
	string[] strArr1, strArr2;

	x = 2; y = 3;
	z = 2; w = 6;
	return x + z;
}
