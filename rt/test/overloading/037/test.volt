module test;

struct TestStruct
{
	private mStrings: string[];
	private mIntegers: i32[];

	fn opIndex(key: string) i32
	{
		foreach (i, str; mStrings) {
			if (str == key) {
				return mIntegers[i];
			}
		}
		return 0;
	}

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
	return ts["hello"] - 12;
}
