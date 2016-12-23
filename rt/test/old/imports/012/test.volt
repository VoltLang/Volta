//T compiles:yes
//T retval:42
//T dependency:../deps/m1.volt
// Renames.
module test;

import m1 : exportedVar1 = exportedVar;


int main()
{
	return exportedVar1;
}
