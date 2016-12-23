//T compiles:yes
//T retval:0
// null not handled to constructors.
module test;


class Clazz
{
	this(string t)
	{
		return;
	}
}

int main()
{
	auto c = new Clazz(null);
	return 0;
}
