//T compiles:no
module test;


int main()
{
	static is(int == int);
	static is(int == char[]);
}
