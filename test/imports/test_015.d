//T compiles:yes
//T retval:42
//T dependency:m1.d
//T has-passed:no
// Import contexts.

module test_015;

import ctx = m1;


int main()
{
	return ctx.exportedVar;
}
