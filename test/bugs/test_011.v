//T compiles:yes
//T retval:0
//T has-passed:no 
// null not handled to constructors.
module test_001;

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
