//T compiles:yes
//T retval:42
//T dependency:m1.v
// Import contexts.

module test_015;

import ctx = m1;


int main()
{
	return ctx.exportedVar;
}
