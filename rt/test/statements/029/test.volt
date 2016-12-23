//T compiles:yes
//T retval:50
module test;

struct S
{
	int x;
	
	int opSubAssign(y: int)
	{
		return x -= y;
	}
	
	string opSubAssign(y: string)
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
	return s.x;
}
