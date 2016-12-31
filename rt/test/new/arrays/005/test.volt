// Test slicing and copying.
module test;


fn sumArray(str: char[]) i32
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
	ptr := new char;
	str := new char[](4);

	str[] = "TheVoltIsAwesome"[index .. 7];
	ptr[0 .. 1] = "TheVoltIsAwesome"[index .. index+1];

	val: i32 = sumArray(str);
	if (val == 421 && *ptr == 'V')
		return 0;
	else
		return 42;
}
