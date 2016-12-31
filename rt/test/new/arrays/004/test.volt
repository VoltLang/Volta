// Test slicing.
module test;


fn sumArray(str: const(char)[]) i32
{
	sum: u32;
	for (i: u32; i < str.length; i++) {
		sum = sum + str[i];
	}
	return cast(i32)sum;
}

fn main() i32
{
	index: i32 = 3;
	val: i32 = sumArray("TheVoltIsAwesome"[index .. 7]);
	if (val == 421)
		return 0;
	else
		return 42;
}
