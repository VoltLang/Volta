//T compiles:no
module test_021;

enum MEANING_OF_LIFE = 42;

void addOne(ref int a)
{
	a++;
	return;
}

int main()
{
	addOne(MEANING_OF_LIFE);
	return 0;
}
