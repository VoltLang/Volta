module watt.algorithm;

static import std.algorithm;

alias cmpfn = bool function(object.Object, object.Object);

void sort(object.Object[] objects, cmpfn cmp)
{
	std.algorithm.sort!cmp(objects);
}

