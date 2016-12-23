//T compiles:yes
//T retval:5
module test;

struct PrettyPrinter
{
	int x;
	int enter()
	{
		x = 1;
		int printNodes(int node)
		{
			auto t = this;
			auto v = this;
			return t.x + v.x + this.x + node;
		}
		return printNodes(2);
	}
}

int main()
{
	PrettyPrinter pp;
	return pp.enter();
}
