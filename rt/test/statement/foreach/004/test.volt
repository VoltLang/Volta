module test;

fn main() i32
{
	i: i32;
	foreach (0 .. 8) {
		i++;
	}
	return i - 8;
}
