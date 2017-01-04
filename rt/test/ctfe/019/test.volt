module test;

fn foo(f: f32) i32
{
	if (f >= 0.25f) {
		return 0;
	}
	return 3;
}

fn main() i32
{
	return #run foo(0.5f);
}
