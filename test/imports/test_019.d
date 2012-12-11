//T compiles:no
//T dependency:m1.d
// Import contexts.
module test_019;

import ctx = m1 : exportedVar1 = exportedVar;


int main()
{
	return ctx.otherVar;
}
