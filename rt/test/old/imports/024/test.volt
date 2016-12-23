//T compiles:no
//T dependency:../deps/m1.volt
//T dependency:../deps/m6.volt
//T dependency:../deps/m7.volt
// We must go deeper.
module test;

import m7;


int main()
{
	return m6.m1.exportedVar;
}
