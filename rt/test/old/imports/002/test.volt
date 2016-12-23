//T compiles:yes
//T retval:32
//T dependency:../deps/m2.volt
// Other import.
module test;

import m2;


int main()
{
	return exportedVar;
}
