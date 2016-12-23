//T compiles:yes
//T retval:20
module test;

i32 accumulate2(i32 x)
{
	if (x >= 20) {
		return x;
	}
	return accumulate1(x + 1);
}

i32 accumulate1(i32 x)
{
	if (x >= 20) {
		return x;
	}
	return accumulate2(x + 1);
}

i32 twenty()
{
	return accumulate1(0);
}

i32 main()
{
	return #run twenty();
}

