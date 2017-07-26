module test;

class ThreeGetterThatHasThreeThreesToGet
{
public:
	this()
	{
		mThreesRemainingForThisThreeGetterThatHasThreeThreesToGet = 3;
	}

	fn opIndex(i: size_t) i32
	{
		if (i >= mThreesRemainingForThisThreeGetterThatHasThreeThreesToGet) {
			assert(false, "out of threes");
		}
		if (i == mThreesRemainingForThisThreeGetterThatHasThreeThreesToGet - 1) {
			return 2;
		}
		return 3;
	}

	fn opDollar() i32
	{
		return -3;
	}

	fn opSlice(a: i32, b: i32) i32
	{
		return a + b;
	}

	fn opNeg() i32
	{
		if (mThreesRemainingForThisThreeGetterThatHasThreeThreesToGet == 0) {
			assert(false, "out of threes");
		}
		mThreesRemainingForThisThreeGetterThatHasThreeThreesToGet--;
		return -3;
	}

private:
	mThreesRemainingForThisThreeGetterThatHasThreeThreesToGet: size_t;
}

fn main() i32
{
	tgthtttg := new ThreeGetterThatHasThreeThreesToGet();
	a := tgthtttg[5 .. $];
	return a - 2;
}
