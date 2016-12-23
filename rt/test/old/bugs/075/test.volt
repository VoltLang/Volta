//T compiles:yes
//T retval:17
module test;

class WhatWeWant
{
	int importantData;
}

global WhatWeWant _www;

struct ThingThatHoldsWhatWeWant
{
	@property void fabulise(int x)
	{
	}

	@property WhatWeWant fabulise()
	{
		return _www;	
	}
}

int main()
{
	_www = new WhatWeWant();
	ThingThatHoldsWhatWeWant tthwww;
	tthwww.fabulise.importantData = 17;
	return _www.importantData;
}

