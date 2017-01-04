// is test
module test;


fn main() i32
{
	ret: i32;

	// Empty list
	arr: string;

	if (arr is null)
		ret += 1;
	if (arr.ptr is null)
		ret += 1;
	if (arr.length is 0)
		ret += 1;

	// Populated list.
	arr = "four";

	if (arr !is null)
		ret += 1;
	if (arr.ptr !is null)
		ret += 1;
	if (arr.length is 4)
		ret += 1;

	return ret - 6;
}
