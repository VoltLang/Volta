//T compiles:yes
//T retval:42
//T dependency:../deps/m1.volt
//T dependency:../deps/m4.volt
// Constrained public imports.
module test;

import m4 : exportedVar;


int main()
{
	return exportedVar;
}
