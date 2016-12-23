//T compiles:yes
//T retval:60
module test;

i32 sixty()
{
	int a = 0;
	while (a < 6) {
		a++;
	}
	int m = 0;
	for (int i = 0; i <= 10; ++i) {
		m = i;
	}
	return a * m;
}

i32 main()
{
	return #run sixty();
}
