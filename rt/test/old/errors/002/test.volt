//T compiles:no
//T error-line:5
module test;

int foo(string s=42)
{
	return 0;
}

int main()
{
	return foo();
}

