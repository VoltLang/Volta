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
	sfn := cast(fn(Small) i32)takesSmall;

	s : Small;
	s.last = 42;

	return sfn(s) - 42;
}
