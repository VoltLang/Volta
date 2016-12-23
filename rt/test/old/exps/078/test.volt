//T compiles:no
module test;

i32 main()
{
	a := i32(12);
	b := new i32(4, 2);
	return a + *b;
}
