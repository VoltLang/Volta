//T compiles:yes
//T retval:0
// Segfault due to null.
module test;

import core.object : Object;


class Boom
{
	this()
	{
		return;
	}
}

int main()
{
	Object obj = null;
	auto my = cast(Boom) obj;
	return 0;
}
