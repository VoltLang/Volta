module test;

struct S
{
	x: i32;
	
	fn foo()
	{
		fn thisNestedFunctionsNameIsReallyAwfullyLong()
		{
			x = 0;
		}
		thisNestedFunctionsNameIsReallyAwfullyLong();
	}
}

fn main() i32
{
		s: S;
		s.foo();
		return s.x;
}
