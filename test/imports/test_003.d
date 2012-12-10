//T compiles:yes
//T retval:42
//T dependency:m1.d
//T has-passed:yes
// Contained imports.

module test_003;

import mod = m1;


int main()
{
	return mod.exportedVar;
}
