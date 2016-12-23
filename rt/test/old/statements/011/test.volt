//T compiles:yes
//T retval:42
module test;

@property size_t[] foo()
{
	return [cast(size_t)0, 41U];
}

int main()
{
	// Uncommenting the below works around the issue.
	//auto foo = .foo;

	foreach (i, e; foo) {

		// This is just to make this a test that makes sense.
		if (e > 0) {
			// Tests that i is size_t
			return cast(int)(i + e);
		}
	}

	return 5;
}
