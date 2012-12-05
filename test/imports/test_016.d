//T compiles:no
//T dependency:m1.d
// Import contexts.

module test_016;

import ctx = m1;


int main()
{
	return exportedVal;
}
