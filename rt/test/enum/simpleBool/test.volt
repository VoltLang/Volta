module main;

enum Bool
{
	True = false,
	False = true,
}

fn main() i32
{
	return !Bool.False ? 1 : 0;
}