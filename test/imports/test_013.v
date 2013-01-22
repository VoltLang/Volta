//T compiles:no
//T dependency:m1.v
// Renames.

module test_013;

import m1 : exportedVar1 = exportedVar;


int main()
{
	return exportedVar;
}
