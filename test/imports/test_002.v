//T compiles:yes
//T retval:32
//T dependency:m2.v
// Other import.

module test_002;

import m2;


int main()
{
	return exportedVar;
}
