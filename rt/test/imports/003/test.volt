//T compiles:yes
//T retval:42
//T dependency:../deps/m1.volt
// Contained imports.
module test;

import mod = m1;


int main()
{
	return mod.exportedVar;
}
