//T compiles:yes
//T retval:6
// Tests weird interactions with types and array concat.
module test;

enum Enum
{
	v0,
	v1
}

void func(ref Enum[] arr, out Enum value)
{
	value = Enum.v1;
	arr ~= Enum.v1;
	arr ~= value;
}

int main()
{
	Enum[] arr;
	Enum value;

	arr ~= Enum.v1;
	arr ~= 2;
	func(ref arr, out value);

	// 1 + 2 + 1 + 1 + 1
	return arr[0] + arr[1] + arr[2] + arr[3] + value;
}
