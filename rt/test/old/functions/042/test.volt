//T compiles:yes
//T retval:0
module test;

interface NumberGetter
{
	@property fn number() i32;
}

class NumberGetterImplementation : NumberGetter
{
	override @property fn number() i32
	{
		return 0;
	}
}

fn main() i32
{
	ng: NumberGetter = new NumberGetterImplementation();
	return ng.number;
}
