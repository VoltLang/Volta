//T compiles:yes
//T retval:7
module test;

class Sum
{
	int value;

	this(int[] integers...)
	{
		foreach (integer; integers) {
			value += integer;
		}
	}
}

int main()
{
	auto sum = new Sum(7);
	return sum.value;
}

