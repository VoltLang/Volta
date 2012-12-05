//T compiles:no
//T dependency:m1.d
// Renames.

module test_013;

import m1 : exportedVal1 = exportedVal;


int main()
{
	return exportedVal;
}
