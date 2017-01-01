module test;

fn thirty(mult: i32) i32
{
	return 30 * mult;
}

fn sixty(n: i32) i32
{
	two: i32 = 1 + n;
	return thirty(two) - 60;
}

fn main() i32
{
	return #run sixty(1);
}
