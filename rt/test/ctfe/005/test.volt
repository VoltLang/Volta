module test;

fn sixty() i32
{
	a: i32 = 0;
	while (a < 6) {
		a++;
	}
	m: i32 = 0;
	for (i: i32 = 0; i <= 10; ++i) {
		m = i;
	}
	return (a * m) - 60;
}

fn main() i32
{
	return #run sixty();
}
