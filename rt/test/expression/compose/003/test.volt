module test;

enum Enum
{
	Zero,
	One,
}

fn func(arg: i32) string
{
	return new "${Enum.One} + ${arg}";
}

fn main() i32
{
	assert(func(32) == "One + 32");
	return 0;
}
