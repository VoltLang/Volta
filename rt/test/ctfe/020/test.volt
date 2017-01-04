module test;

fn foo(f: f64) i32
{
	if (f >= 0.25) {
		return 0;
	}
	return 3;
}

fn main() i32
{
	return #run foo(0.5);
}
