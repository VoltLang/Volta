//T compiles:yes
//T retval:20
module test;

i32 twenty()
{
	return 20;
}

enum Twenty = #run twenty();

i32 main()
{
	return Twenty;
}

