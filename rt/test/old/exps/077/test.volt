//T compiles:yes
//T retval:16
module test;

i32 main()
{
	a := i32(12);
	b := new i32(4);
	return a + *b;
}
