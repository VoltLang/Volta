module test;

struct TestStruct
{
	val: i32;

	fn opIndexAssign(v: i32, v2: i32) i32
	{
		val = v2;
		return v2;
	}

	fn opIndex(v: i32) i32
	{
		return val + v;
	}
}

fn main() i32
{
	ts: TestStruct;
	ts[2] >>>= 1;
	return ts[0] - 1;
}