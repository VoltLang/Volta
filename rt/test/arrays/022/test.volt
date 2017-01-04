module test;

fn sum(ignored: bool, integers: i32[]...) i32
{
	retval: i32;
	for (i: size_t = 0; i < integers.length; i++) {
		retval += integers[i];
	}
	return retval;
}

fn main() i32
{
	x: i32 = 3;
	a := [1, 2, 3];
	return (sum(true, 1, x, 3) + sum(false, a)) == 13 ? 0 : 1;
}

