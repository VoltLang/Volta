//T compiles:no
module test;


int main()
{
	char[][1] foo;
	foo[0] = "four";
	return cast(int)foo[0].length;
}
