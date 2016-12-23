//T compiles:no
//T dependency:../deps/m1.volt
//T dependency:../deps/m2.volt
// Multiple imports per import deprecated.
module test;

import m1, m2;


int main()
{
	return exportedVar;
}
