//T compiles:yes
//T retval:42
//T dependency:m1.d
//T has-passed:no
// Import contexts.

module test_017;

import ctx = m1 : exportedVal1 = exportedVar;


int main()
{
	return ctx.exportedVal1;
}
