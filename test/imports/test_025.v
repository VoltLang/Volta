//T compiles:yes
//T retval:42
//T dependency:m1.v
//T dependency:m8.v
// Non-public import rebind.

module test_025;

import m8;


int main()
{
	return ctx.exportedVar;
}
