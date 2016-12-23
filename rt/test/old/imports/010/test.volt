//T compiles:no
//T dependency:../deps/m1.volt
//T dependency:../deps/m4.volt
// Constrained public imports.
module test;

import m4 : otherVar;


int main()
{
	return exportedVar;
}
