//T compiles:yes
//T retval:74
//T dependency:../deps/m1.volt
//T dependency:../deps/m2.volt
// Multiple renames.
module test;

import m1 : exportedVar1 = exportedVar;
import m2 : exportedVar2 = exportedVar;


int main()
{
	return exportedVar1 + exportedVar2;
}
