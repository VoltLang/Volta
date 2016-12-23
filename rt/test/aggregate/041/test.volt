//T compiles:yes
//T retval:42
module test;


struct Small
{
	a, b, c, last : i32;
}

fn takesSmall(i32, i32, i32, last : i32) i32
{
	return last;
}


int main()
{
	sfn := cast(i32 function(Small))takesSmall;

	s : Small;
	s.last = 42;

	return sfn(s);
}
