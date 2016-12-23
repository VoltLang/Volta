//T compiles:yes
//T retval:42
module test;


int main()
{
	int[4] elements;
	foreach (i, ref e; elements) {
		e = 42;
	}

	return elements[3];
}
