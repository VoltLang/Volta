//T requires:sysvamd64
module test;

extern (C) fn SumVoltIntegerArray(array: i32[]) i32
{
	sum: i32;
	sum = cast(i32)array.length;
	return sum;
}

fn main() i32
{
	return SumVoltIntegerArray(null);
}
