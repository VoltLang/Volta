module test;

fn x() i32
{
	j: i32;
	foreach (i; 0 .. 10) {
		j += i;
	}
	return j - 45;
}

fn main() i32
{
	return #run x();
}
