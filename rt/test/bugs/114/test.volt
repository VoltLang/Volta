module test;

class Other
{
	// And this is also needed.
	@property fn value() i32 { return 42; }
}

class This
{
	other: Other;

	// There need to be two functions here.
	@property fn first() Other { return other; }
	// Removing this function fixes the error.
	@property fn first(Other) Other { return other; }

	fn func() i32
	{
		// The if case explodes in the backend.
		if (first.value == 0) {
			return 9;
		}
		// This fails in the frontend.
		return first.value;
	}
}


fn main() i32
{
	t := new This();
	t.other = new Other();
	return t.func() - 42;
}
