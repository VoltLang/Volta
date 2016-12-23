//T compiles:no
//T dependency:../deps/m1.volt
// Renames.
module test;

import m1 : exportedVar1 = exportedVar;


int main()
{
	return exportedVar;
}
