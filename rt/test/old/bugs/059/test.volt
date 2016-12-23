//T compiles:yes
//T dependency:../deps/b.volt
//T retval:3
module test;

import token.location;

void foo(Location)
{
}

int main()
{
	Location l;
	foo(l);
	return 3;
}

