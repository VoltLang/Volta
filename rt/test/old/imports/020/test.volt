//T compiles:no
//T dependency:../deps/m1.volt
//T dependency:../deps/m3.volt
// More private imports, old dmd bug.
module test;

import m3;


int main()
{
	return m1.exportedVar;
}
