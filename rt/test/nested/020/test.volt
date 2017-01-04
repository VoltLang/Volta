module test;


struct S
{
	mustSet: i32;
}

fn main() i32
{
	s: S;

	s.mustSet = 0;

	assert(s.mustSet == 0);

	{
		// Need a function to make the variable nested
		// But it must be inside a block statement and
		// not in the root of the function.
		// No need to call the function.
		fn nest()
		{
			s.mustSet = 1;
		}

	}

	assert(s.mustSet == 0);

	return s.mustSet;
}
