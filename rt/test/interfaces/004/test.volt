//T compiles:no
module test;

interface Wow
{
	void doge();
}

class Such : Wow
{
	int doge()
	{
		return 42;
	}
}

int main()
{
	return (new Such()).doge();
}
