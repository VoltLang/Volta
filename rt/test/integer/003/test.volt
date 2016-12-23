//T compiles:no
module test;


int main()
{
	byte byteVar;
	uint uintVar;

	// mixing signed ness.
	auto var = byteVar + uintVar;
	return 0;
}
