module test;

struct Struct
{
	a: i32;
	b: i16;
}

fn main() i32
{
	structArray: Struct[];
	foreach (i; 0 .. 10000) {
		structInstance: Struct;
		structArray ~= structInstance;
	}
	return 0;
}

