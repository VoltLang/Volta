//T compiles:yes
//T retval:100
// Tests float literals and truncating casts.
module test;


int main()
{
	float f = 100.56f;
	return cast(int) f;
}
