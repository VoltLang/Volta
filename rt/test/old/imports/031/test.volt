//T compiles:yes
//T retval:42
//T dependency:../deps/bug_031_m1.volt
//T dependency:../deps/bug_031_m2.volt
//T dependency:../deps/bug_031_m3.volt
module test;

import bug_031_m1;
import bug_031_m2;


int main()
{
	return func();
}
