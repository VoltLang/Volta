module test;

class IntegerHoldingInstanceVersionThree
{
	integerThatIsBeingHeldByIntegerHoldingInstance: i32 = 0;

	this()
	{
	}
}

int main()
{
	integer := new IntegerHoldingInstanceVersionThree();
	return integer.integerThatIsBeingHeldByIntegerHoldingInstance;
}

