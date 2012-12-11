//T compiles:yes
//T retval:42
//T dependency:m1.d
//T has-passed:yes
// Import contexts.

module test_017;

import ctx = m1 : exportedVar1 = exportedVar;


int main()
{
	return ctx.exportedVar1;
}
