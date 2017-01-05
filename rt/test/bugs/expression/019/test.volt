module test;

fn main() i32
{
	sum: i32;
	foreach (a; [1, 2, 3]) {
		foreach (b; [1, 1, 2]) {
			sum += b * a;
		}
	}
	return sum - 24;
}

