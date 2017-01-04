module test;

struct S
{
	x: i32;
	
	fn opAddAssign(y: i32) i32
	{
		return x += y;
	}
	
	fn opAddAssign(y: string) string
	{
		if (y == "multiply by two") {
			x *= 2;
		}
		return "please do not do this in real code";
	}
}

fn main() i32
{
	s: S;
	s += 2;
	s += "multiply by two";
	return s.x - 4;
}
