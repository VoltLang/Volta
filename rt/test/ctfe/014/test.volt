//T compiles:yes
//T retval:10
module test;

i32 accumulate(i32 x)
{
	if (x == 10) {
		return x;
	}
	return accumulate(x + 1);
}

i32 ten()
{
	return accumulate(0);
}

i32 main()
{
	return #run ten();
}

