//T compiles:no
//T dependency:m1.d
// Renames.

module test_013;

import m1 : exportedVar1 = exportedVar;


int main()
{
	return exportedVar;
}
