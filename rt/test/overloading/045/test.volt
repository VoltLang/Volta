module test;

struct TestStruct
{
	val: size_t;

	fn opSliceAssign(a: size_t, b: size_t, c: i32) i32
	{
		val = cast(size_t)c;
		return cast(i32)val;
	}

	fn opSliceAssign(a: size_t, b: size_t, c: string) i32
	{
		val -= 3;
		return cast(i32)val;
	}

	fn opIndex(a: size_t) i32
	{
		return cast(i32)a;
	}

	fn opSlice(a: size_t, b: size_t) i32
	{
		return cast(i32)(a + b + val);
	}
}

fn main() i32
{
	ts: TestStruct;
	ts[1 .. 6] = ts[6];
	ts[1 .. 6] = "hello";
	return ts[1 .. 6] - ts[10];
}
