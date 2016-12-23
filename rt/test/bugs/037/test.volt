//T compiles:yes
//T retval:7
module test;

void foo(const(ubyte)**)
{
	return;
}

int main()
{
	ubyte** data;
	foo(data);
	return 7;
}

