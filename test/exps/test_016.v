//T compiles:no
// Mismatched types.
module test_016;

int main()
{
	return true ? 3 : "foo";
}
