//T compiles:yes
//T retval:42
//T dependency:m1.d
// Import contexts.

module test_015;

import ctx = m1;


int main()
{
	return ctx.exportedVal;
}
