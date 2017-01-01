module test;

fn six() i32
{
	a: i32 = 2;
	return (4 + a) - 6;
}

fn main() i32
{
	return #run six();
}
