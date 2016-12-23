//T compiles:no
// Non overriding with no parent.
module test;


class Bar
{
	override int x()
	{
		return 3;
	}
}

int main()
{
	auto foo = new Bar();
	return foo.x();
}
