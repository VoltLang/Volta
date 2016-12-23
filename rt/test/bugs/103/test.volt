//T compiles:yes
//T retval:3
module test;

global int integer;

void addParent(int parent)
{
	integer = parent;
}

class CFGBuilder
{
	@property void block(int b)
	{
	}

	/// Returns the last block added.
	@property int block()
	{
		return 3;
	}

	void enter()
	{
		void addTarget(int i)
		{
			addParent(block);
		}
		addTarget(0);
	}
}

int main()
{
	auto cfg = new CFGBuilder();
	cfg.enter();
	return integer;
}

