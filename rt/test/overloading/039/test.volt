//T macro:expect-failure
//T check:does not define operator function 'opSliceAssign'
module test;

struct TestStruct
{
	val: size_t;

	fn opSlice(a: size_t, b: size_t) i32
	{
		return cast(i32)(a + b + val);
	}
}

fn main() i32
{
	ts: TestStruct;
	ts[1 .. 6] = 13;
	return ts[1 .. 6];
}
