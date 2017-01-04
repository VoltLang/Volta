// Auto bug
module test;


fn funcReturnsPointer() void* { ptr: void*; return ptr; }

fn main() i32
{
	ptr := funcReturnsPointer();

	return 0;
}
