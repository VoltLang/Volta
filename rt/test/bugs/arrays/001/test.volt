module test;


fn main() i32
{
	// scope is needed for this bug.
	arr: scope string[] = ["s"];
	var: string[];
	var ~= arr;

	return var[0].ptr !is arr[0].ptr;
}
