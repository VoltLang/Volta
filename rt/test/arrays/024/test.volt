// Tests weird interactions with types and array concat.
module test;

enum Enum
{
	v0,
	v1
}

fn func(ref arr: Enum[], out value: Enum)
{
	value = Enum.v1;
	arr ~= Enum.v1;
	arr ~= value;
}

fn main() i32
{
	arr: Enum[];
	value: Enum;

	arr ~= Enum.v1;
	arr ~= 2;
	func(ref arr, out value);

	// 1 + 2 + 1 + 1 + 1
	return (arr[0] + arr[1] + arr[2] + arr[3] + value == 6) ? 0 : 1;
}
