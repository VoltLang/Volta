//T compiles:yes
//T retval:2
module test;

import core.object : Object;

void frozknobble(out Object obj)
{
	Object obj2 = obj;
}

int main()
{
	auto obj = new Object();
	frozknobble(out obj);
	return 2;
}

