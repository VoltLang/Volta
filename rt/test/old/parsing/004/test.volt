//T compiles:no
module test;

int main()
{
	() @trusted {} ();
	return 0;
}
