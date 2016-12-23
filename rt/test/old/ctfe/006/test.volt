//T compiles:yes
//T retval:60
module test;

i32 thirty()
{
	return 30;
}

i32 sixty()
{
	return thirty() * 2;
}

i32 main()
{
	return #run sixty();
}
