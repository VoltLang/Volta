//T compiles:no
//T retval:42
//T dependency:../deps/m1.volt
//T dependency:../deps/m8.volt
// Non-public import rebind.
module test;

import m8;


int main()
{
	return ctx.exportedVar;
}
