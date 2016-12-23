//T compiles:yes
//T retval:4
module test;

struct S
{
	int x;
	
	int opAddAssign(y: int)
	{
		return x += y;
	}
	
	string opAddAssign(y: string)
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
	return s.x;
}
