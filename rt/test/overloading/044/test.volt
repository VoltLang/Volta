module test;

struct TestStruct
{
	val: size_t;

	fn opSliceAssign(a: size_t, b: size_t, c: size_t) i32
	{
		val = 5;
		return cast(i32)val;
	}

	fn opSliceAssign(a: size_t, b: size_t, c: string) i32
	{
		val -= 3;
		return cast(i32)val;
	}

	fn opSlice(a: size_t, b: size_t) i32
	{
		return cast(i32)(a + b + val);
	}
}

fn main() i32
{
	ts: TestStruct;
	ts[1 .. 6] = 13;
	ts[1 .. 6] = "hello";
	return ts[1 .. 6] - 9;
}
