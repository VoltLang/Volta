//T requires:sysvamd64
module test;

extern (C) fn SumVoltIntegerArray(array: i32[]) i32
{
	sum: i32;
	foreach (element; array) {
		sum += element;
	}
	return sum;
}

fn main() i32
{
	array := [1, 2, 3];
	return SumVoltIntegerArray(array) - 6;
}
