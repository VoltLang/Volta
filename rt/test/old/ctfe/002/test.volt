//T compiles:no
//T error-line:7
module test;

i32 main()
{
	int nested() { return 7; }
	return #run nested();
}
