//T compiles:yes
//T retval:0
// Segfault due to null.
module test_015;

class Boom
{
	this()
	{
		return;
	}
}

int main()
{
	object.Object obj = null;
	auto my = cast(Boom) obj;
	return 0;
}
