//T compiles:no
// Shouldn't be able to treat i as a pointer.
module test;


void addOne(ref int i)
{
	int* ip = i;
	return;
}

int main()
{
	int i = 29;
	addOne(i);
	return i;
}
