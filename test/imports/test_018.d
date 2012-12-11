//T compiles:no
//T dependency:m1.d
// Import contexts.
module test_018;

import ctx = m1 : exportedVar1 = exportedVar;


int main()
{
	return ctx.exportedVar;
}
