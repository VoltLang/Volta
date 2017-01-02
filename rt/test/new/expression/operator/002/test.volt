module test;

struct S
{
	x: i32;
	
	fn opSubAssign(y: i32) i32
	{
		return x -= y;
	}
	
	fn opSubAssign(y: string) string
	{
		if (y == "divide by two") {
			x /= 2;
		}
		return "PLEASE do not do this in real code";
	}
}

fn main() i32
{
	s: S;
	s.x = 125;
	s -= 25;
	s -= "divide by two";
	return s.x - 50;
}
