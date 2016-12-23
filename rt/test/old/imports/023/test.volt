//T compiles:no
//T dependency:../deps/m1.volt
//T dependency:../deps/m6.volt
// Static public import in another module.
module test;

import m6;


int main()
{
	return m1.exportedVar;
}
