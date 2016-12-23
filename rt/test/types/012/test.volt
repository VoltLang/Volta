//T compiles:yes
//T retval:42
// Tests correct functioning of typeof.
module test;


int main()
{
	int i = 1;
	typeof(i++) AnInteger = 41;  // i should not mutate.
	return AnInteger + i;
}
