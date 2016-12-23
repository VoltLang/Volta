//T compiles:no
// Invalid key type accessing aa.
module test;


int main()
{
	int[int] aa;
	return aa["volt"];
}
