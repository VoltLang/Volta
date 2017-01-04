module test;

fn six() i32
{
	a: i32 = 2;
	if (a == 2) {
		return 0;
	}
	return 2 + a;
}

fn main() i32
{
	return #run six();
}
