//T compiles:yes
//T retval:42
//T has-passed:yes
// Test converting int implicitly to float.
module test;


int main()
{
	int a = 42;
	float b;
	float c = b + a;
	return cast(int)c;
}
