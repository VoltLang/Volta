//T compiles:no
//T dependency:../deps/m1.volt
//T dependency:../deps/m9.volt
// Non-public import rebind.
module test;

import m9;


int main()
{
	return exportedVar1;
}
