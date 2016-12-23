//T compiles:yes
//T retval:41
//T dependency:../deps/m12.volt
//T dependency:../deps/m13.volt
module test;

import ir = m12;

int main()
{
	return cast(int) ir.retval;
}

