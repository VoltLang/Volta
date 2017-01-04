module test;

fn ichi() i32[50]
{
	x: i32[50];
	x[4] = 35;
	return x;
}

fn ni() i32[]
{
	x := new i32[](50);
	x[4] = 3;
	return x;
}

fn main() i32
{
	hitotu := ichi();
	futatu := ni();
	return hitotu[4] + futatu[4] - 38;
}

