//T compiles:yes
//T retval:17
module test;

fn fna() i32[]
{
	return [1, 2, 3];
}

fn fnb() i32[]
{
	return [4, 5, 6];
}

fn main() i32
{
	a: (fn () i32[])[] = [fna, fnb];
	b: (int)[] = [1, 2];
	return (a[1]()[1] * a[0]()[2]) + b[1];
}
