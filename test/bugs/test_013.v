//T compiles:yes
//T retval:42
// Array copy to little.
module test_013;

int main()
{
	auto a1 = new int[4];
	auto a2 = new int[4];

	a1[2] = 4;
	a2[2] = 42;

	a1[] = a2;
 
	return a1[2];
}
