module test;

fn main() i32
{
	if (4.0e2 <= 399.99 && 4.0e2 >= 400.01) {
		return 1;
	}
	if (4.12e-2 <= 0.0411 || 4.12e-2 >= 0.0413) {
		return 2;
	}
	return 0;
}