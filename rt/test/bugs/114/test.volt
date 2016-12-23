//T compiles:yes
//T retval:42
module test;

class Other
{
	// And this is also needed.
	@property int value() { return 42; }
}

class This
{
	Other other;

	// There need to be two functions here.
	@property Other first() { return other; }
	// Removing this function fixes the error.
	@property Other first(Other) { return other; }

	int func()
	{
		// The if case explodes in the backend.
		if (first.value == 0) {
			return 9;
		}
		// This fails in the frontend.
		return first.value;
	}
}


int main()
{
	auto t = new This();
	t.other = new Other();
	return t.func();
}
