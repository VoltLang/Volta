//T compiles:yes
//T retval:0
module test;


// immutable somehow explodes.
global immutable(ubyte)[3] arr;

int main()
{
	return arr[0];
}
