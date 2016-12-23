//T compiles:no
module test;


int main()
{
	char c;
	scope int* p;
	p = &c;
	return 3;
}
