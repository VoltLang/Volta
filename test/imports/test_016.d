//T compiles:no
//T dependency:m1.d
//T has-passed:no
// Import contexts.

module test_016;

import ctx = m1;


int main()
{
	return exportedVar;
}
