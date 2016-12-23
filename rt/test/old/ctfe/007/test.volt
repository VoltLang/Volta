//T compiles:yes
//T retval:40
module test;

i32 dbl(int n)
{
	return n * 2;
}

i32 main()
{
	return #run dbl(20);
}
