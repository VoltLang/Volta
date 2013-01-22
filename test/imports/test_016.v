//T compiles:no
//T dependency:m1.v
// Import contexts.

module test_016;

import ctx = m1;


int main()
{
	return exportedVar;
}
