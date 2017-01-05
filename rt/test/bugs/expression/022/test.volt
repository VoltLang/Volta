module test;

fn bar(x: i32[]) i32
{
	return x[0];
}

fn foo(out x: i32[]) i32
{
	x = [7];
	return bar(x);
}

fn main() i32
{
	x: i32[];
	return foo(out x) - 7;
}
