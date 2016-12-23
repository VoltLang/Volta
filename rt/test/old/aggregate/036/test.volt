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
	this()
	{
		// Requires at least one explicit call to super()
		// Because no implicit can be inserted at the end.
	}
}

int main()
{
	auto b = new Base();
	return b.var + 37;
}
