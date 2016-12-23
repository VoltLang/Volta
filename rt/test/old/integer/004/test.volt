//T compiles:yes
//T retval:4
module test;


int main()
{
	ubyte ubyteVar = 4;
	uint uintVar = 1;

	uintVar = uintVar << ubyteVar;
	uintVar = uintVar >> 2;

	return cast(int)uintVar;
}
