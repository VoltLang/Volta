//T compiles:yes
//T retval:3
// Ensures that test 2 isn't a fluke.
module test;


int main()
{
	if (true) {
		int x = 3;
		return x;
	} else {
		int x = 4;
		return x;
	}
}
