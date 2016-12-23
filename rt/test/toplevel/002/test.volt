//T compiles:yes
//T retval:42
module test;

class IntegerHoldingInstanceVersionThree
{
	int integerThatIsBeingHeldByIntegerHoldingInstance = 42;

	this()
	{
	}
}

int main()
{
	auto integer = new IntegerHoldingInstanceVersionThree();
	return integer.integerThatIsBeingHeldByIntegerHoldingInstance;
}

