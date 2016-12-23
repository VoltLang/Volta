//T compiles:no
module test;


class Super
{
public:
	int var;

public:
	this(int)
	{
		this.var = 5;
	}
}

class Base : Super
{
	// Need a explicit this because no default can be generated.
}

int main()
{
	auto b = new Base();
	return b.var + 37;
}
