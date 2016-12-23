//T compiles:no
//T dependency:../deps/m1.volt
// Import contexts.
module test;

import ctx = m1;


int main()
{
	return exportedVar;
}
