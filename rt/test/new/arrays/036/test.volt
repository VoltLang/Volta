module test;


fn main() i32
{
	sarr: i32[4];
	// Make sure that arr refer to sarr's storage
	arr: i32[] = sarr;

	arr[3] = 42;

	return (sarr[3] == 42) ? 0 : 1;
}
