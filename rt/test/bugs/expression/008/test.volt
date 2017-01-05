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
	obj: Object = null;
	my := cast(Boom) obj;
	return 0;
}
