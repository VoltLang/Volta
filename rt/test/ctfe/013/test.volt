//T compiles:yes
//T retval:24
module test;

i32 frimulize(i32 a, i32 b)
{
	return a + b;
}

i32 frobulate(i32 a)
{
	return frimulize(12, a * 2);
}

i32 main()
{
	return #run frobulate(6);
}
