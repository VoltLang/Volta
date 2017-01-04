module test;


fn main() i32
{
	// Segfaults the compiler
	// Just turn this into a while(true)
	for (;;) {
		return 0;
	}
	return 42;
}
