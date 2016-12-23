//T retval:0
//T compiles:yes
// Overload doesn't work on arrays of arrays.
module bugs;


int main()
{
	return func("bug here");
}

int func(string f)
{
	return 0;
}

int func(string[] f)
{
	return 3;
}
