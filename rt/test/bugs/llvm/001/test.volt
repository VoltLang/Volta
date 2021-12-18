// LLVM 12 introduced typed enum byVal attributes on struct arguments.
module test;

struct TheStruct
{
	field1: i32;
	field2: i32;
	field3: i32;
	field4: i32;
	field5: i32; // Needs to be larger then 16 bytes to trigger byVal usage.
}

// Has to be extern C, we don't use byVal on Volt calling conventions.
extern(C) fn func(TheStruct);

fn main() i32
{
	return 0;
}
