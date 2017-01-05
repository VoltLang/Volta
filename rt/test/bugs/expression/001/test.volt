// Segfault
module test;


fn main() i32
{
	i := 0;
	id := typeid(typeof(i)); // Causes a segfault.

	return 0;
}
