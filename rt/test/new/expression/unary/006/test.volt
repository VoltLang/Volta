module test;


fn main() i32
{
	arg: i32[] = [3, 4, 5];
	i: size_t = 0;

	// Make sure that side effects only happens once.
	arg = new arg[0 .. ++i];

	return cast(i32)i - 1;
}
