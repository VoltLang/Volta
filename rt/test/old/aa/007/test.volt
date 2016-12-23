//T compiles:no
// Assigning to invalid value type.
module test;


int main()
{
	int[int] aa;
	string x = aa["volt"];
	return 1;
}
