module test;

class ThreeGetterThatHasThreeThreesToGet
{
public:
	this()
	{
		mThreesRemainingForThisThreeGetterThatHasThreeThreesToGet = 3;
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
	a := -tgthtttg;
	return a + 3;
}
