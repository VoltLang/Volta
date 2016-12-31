// Test string literals.
module test;


fn sumArray(str: const(char)[]) i32
{
	sum: u64;
	for (u32 i; i < str.length; i++) {
		sum = sum + str[i];
	}
	return cast(i32)sum;
}

fn main() i32
{
	val: i32 = sumArray("Volt");
	if (val == 421)
		return 0;
	else
		return 42;
}
