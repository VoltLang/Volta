module test;


fn main() i32
{
	// scope is needed for this bug.
	arr: scope string[] = ["s"];
	var: string[];
	var ~= arr;

	return cast(void*)var[0].ptr !is cast(void*)arr[0].ptr;
}
