//T compiles:yes
//T retval:42
module test;


i32 func(out u32[2] vec)
{
	return 20;
}

i32 func(out u32[3] vec)
{
	return 22;
}

i32 func(out u32[4] vec)
{
	return 0;
}

i32 main()
{
	v2 : u32[2];
	v3 : u32[3];

	// Static arrays should be able to overload properly
	return func(out v2) + func(out v3);
}
