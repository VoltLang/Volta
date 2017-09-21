//T macro:expect-failure
//T check:does not define operator
module test;

struct TestStruct
{
	private mStrings: string[];
	private mIntegers: i32[];

	fn opIndexAssign(key: string, val: i32) i32
	{
		mStrings ~= key;
		mIntegers ~= val;
		return val;
	}
}

fn main() i32
{
	ts: TestStruct;
	ts["hello"] = 12;
	return ts["hello"];
}
