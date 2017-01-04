module test;


enum named { a, b, c }

fn doSomething(n: named) i32
{
	if (n == named.c) {
		return 11;
	}
	return 5;
}

fn main() i32
{
	return doSomething(named.c) + cast(int) named.b - 12;
}
