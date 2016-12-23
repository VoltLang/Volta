//T compiles:yes
//T retval:42
//T dependency:../deps/m1.volt
// Constrained imports.
module test;

import m1 : exportedVar;


int main()
{
	return exportedVar;
}
