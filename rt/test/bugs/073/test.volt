module test;

enum sss = 24;

struct S {
	s: i32;
}

struct SS {
	s: S;
}

fn supplyS() S
{
	s: S;
	s.s = 12;
	return s;
}

global ss: SS;

fn globalS() SS
{
	return ss;
}

fn main() i32
{
	globalS().s.s = 5;
	supplyS().s = sss;
	return supplyS().s + globalS().s.s - 12;
}

