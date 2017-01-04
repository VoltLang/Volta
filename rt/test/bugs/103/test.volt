module test;

global integer: i32;

fn addParent(parent: i32)
{
	integer = parent;
}

class CFGBuilder
{
	@property fn block(b: i32)
	{
	}

	/// Returns the last block added.
	@property fn block() i32
	{
		return 3;
	}

	fn enter()
	{
		fn addTarget(i: i32)
		{
			addParent(block);
		}
		addTarget(0);
	}
}

fn main() i32
{
	cfg := new CFGBuilder();
	cfg.enter();
	return integer - 3;
}

