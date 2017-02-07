module test;

enum
{
	A = 0u
}

enum
{
	B = A
}

fn main() i32
{
	return B;
}
