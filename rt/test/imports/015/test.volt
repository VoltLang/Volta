//T compiles:yes
//T retval:42
//T dependency:../deps/m1.volt
// Import contexts.
module test;

import ctx = m1;


int main()
{
	return ctx.exportedVar;
}
