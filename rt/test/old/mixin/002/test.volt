//T compiles:yes
//T retval:42
// basic function mixin test.
module test;


mixin function Bar()
{
	int i = 3;

	for (int g; g < 4; g++) {
		i *= 5;
	}
	
	return i;
}

int main()
{
	return 42;
}
