//T compiles:no
// @loadDynamic test.
module test_006;


@loadDynamic int func(int val)
{
	return 21 + val;
}

int main()
{
	return 0;
}
