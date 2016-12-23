//T compiles:yes
//T retval:42
//T dependency:../deps/m1.volt
//T dependency:../deps/m4.volt
// Public imports.
module test;

import m4;


int main()
{
	return exportedVar;
}
