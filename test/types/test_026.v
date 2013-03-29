//T compiles:no
module test_026;

enum Foo : int {
	v1 = 0xffffffff,
	v2 = 0x1ffffffff, // Error can't fit long into int.
}

int main()
{
	return 0;
}
