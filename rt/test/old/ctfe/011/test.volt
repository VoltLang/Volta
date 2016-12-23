//T compiles:yes
//T retval:60
module test;

i32 thirty(int mult)
{
	return 30 * mult;
}

i32 sixty(int n)
{
	i32 two = 1 + n;
	return thirty(two);
}

i32 main()
{
	return #run sixty(1);
}
