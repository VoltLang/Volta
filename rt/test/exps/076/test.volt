//T compiles:yes
//T retval:40
module test;

i32 main()
{
	a := 32;
	b : i32 = 7;
	c, d : i32;
	c = 1;
	return a + b + c + d;
}
