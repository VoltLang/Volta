//T compiles:no
//T dependency:m1.d
// Import contexts.
module test_019;

import ctx = m1 : exportedVal1 = exportedVal;


int main()
{
	return ctx.otherVal;
}
