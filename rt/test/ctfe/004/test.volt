//T compiles:yes
//T retval:6
module test;

i32 six()
{
	int a = 2;
	if (a == 2) {
		return 6;
	}
	return 2 + a;
}

i32 main()
{
	return #run six();
}
