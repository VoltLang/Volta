//T default:no
//T macro:expect-failure
//T check:expected lvalue to out parameter
module test;

fn foo(out var: bool)
{
	var = true;
}

fn main() i32
{
	foo(true);
	return 0;
}
