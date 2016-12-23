//T compiles:yes
//T retval:42
//T dependency:../deps/m1.volt
// Basic imports.
module test;

import m1;


int main()
{
	return exportedVar;
}
