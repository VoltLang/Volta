//T default:no
//T macro:expect-failure
//T check:nested functions may not have nested functions
module test;

fn main() i32
{
	fn foo(x: i32) i32
	{
		fn bar(x: i32) i32
		{
			return x;
		}
		return bar(x);
	}
	return foo(32);
}
