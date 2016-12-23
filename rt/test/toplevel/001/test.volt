//T compiles:yes
//T retval:13
module test;

global int x;

global this()
{
	x = 13;
	return;
}

global ~this()
{
	x = 2;
	return;
}

int main()
{
	return x;
}

