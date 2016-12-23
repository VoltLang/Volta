//T compiles:yes
//T retval:5
module test;

u8 x()
{
	return cast(u8)261;
}

i32 main()
{
	int y = #run x();
	return y;
}
