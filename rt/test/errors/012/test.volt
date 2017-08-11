//T default:no
//T macro:expect-failure
//T check:expected lvalue to ref parameter
module test;

fn foo(ref var: bool)
{
	var = true;
}

fn main() i32
{
	foo(true);
	return 0;
}
