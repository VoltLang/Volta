//T compiles:yes
//T retval:21
module test;

int main()
{
	static assert(true, "if you can read this, I'm not working!");
	return 21;
}

