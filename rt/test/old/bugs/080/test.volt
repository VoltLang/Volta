//T compiles:yes
//T retval:5
module test;

int wf(string[] strings...)
{
	return cast(int) strings[0].length;
}

int wf(int x)
{
	return 7;
}

int main()
{
	return wf("hello");
}

