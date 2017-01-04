// Implicit int conversion gone wrong.
module test;


fn main() i32
{
	t: u8 = 4;
	if (t == 4)
		return 0;
	return 42;
}
