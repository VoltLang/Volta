//T compiles:yes
//T retval:42
//T dependency:m1.d
// Import contexts.

module test_017;

import ctx = m1 : exportedVal1 = exportedVal;


int main()
{
	return ctx.exportedVal1;
}
