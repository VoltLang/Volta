//T compiles:yes
//T retval:6
module test;

i32 six()
{
	int a = 2;
	return 4 + a;
}

i32 main()
{
	return #run six();
}
