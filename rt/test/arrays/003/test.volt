//T compiles:yes
//T retval:4
// Test slicing.
module test;


int main()
{
	char[] str = new char[](6);
	char[] otherStr = str[0 .. 4];

	return cast(int)otherStr.length;
}
