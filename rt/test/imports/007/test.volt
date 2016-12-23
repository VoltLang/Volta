//T compiles:no
//T dependency:../deps/m1.volt
//T dependency:../deps/m3.volt
// Import leaks.
module test;

import m3 : exportedVar;


int main()
{
	return exportedVar;
}
