module test;

class WhatWeWant
{
	importantData: i32;
}

global _www: WhatWeWant;

struct ThingThatHoldsWhatWeWant
{
	@property fn fabulise(x: i32)
	{
	}

	@property fn fabulise() WhatWeWant
	{
		return _www;	
	}
}

fn main() i32
{
	_www = new WhatWeWant();
	ThingThatHoldsWhatWeWant tthwww;
	tthwww.fabulise.importantData = 17;
	return _www.importantData - 17;
}

