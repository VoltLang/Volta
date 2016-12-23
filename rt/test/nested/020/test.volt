//T compiles:yes
//T retval:1
module test;


struct S
{
	int mustSet;
}

int main()
{
	S s;

	s.mustSet = 1;

	assert(s.mustSet == 1);

	{
		// Need a function to make the variable nested
		// But it must be inside a block statement and
		// not in the root of the function.
		// No need to call the function.
		void nest()
		{
			s.mustSet = 0;
		}

	}

	assert(s.mustSet == 1);

	return s.mustSet;
}
