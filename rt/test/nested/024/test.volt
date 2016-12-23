//T compiles:yes
//T retval:5
module test;

struct S
{
	int x;
	
	fn foo()
	{
		fn thisNestedFunctionsNameIsReallyAwfullyLong()
		{
			x = 5;
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
