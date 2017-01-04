module test;

struct PrettyPrinter
{
	x: i32;
	fn enter() i32
	{
		x = 1;
		fn printNodes(node: i32) i32
		{
			t := this;
			v := this;
			return t.x + v.x + this.x + node;
		}
		return printNodes(2);
	}
}

fn main() i32
{
	pp: PrettyPrinter;
	return pp.enter() - 5;
}
