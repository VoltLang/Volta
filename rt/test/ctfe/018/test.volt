module test;

fn foo() f64
{
	return 0.0 + 0.5;
}

fn main() i32
{
	return (#run foo()) >= 0.25 ? 0 : 3;
}
