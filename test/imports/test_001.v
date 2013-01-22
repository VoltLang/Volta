//T compiles:yes
//T retval:42
//T dependency:m1.v
// Basic imports.

module test_001;

import m1;


int main()
{
	return exportedVar;
}
