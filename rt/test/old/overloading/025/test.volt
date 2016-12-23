//T compiles:no
module test;

class S
{
	int x;

	this(int y=0)
	{
		x = y;
	}

	this()
	{
		x = 34;
	}
}

int main(string[] args)
{
	S s = new S();
	return s.x;
}
