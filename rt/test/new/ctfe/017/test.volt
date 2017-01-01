module test;

fn foo() f32
{
	return 0.0f + 0.5f;
}

fn main() i32
{
	return (#run foo()) >= 0.25f ? 0 : 3;
}
