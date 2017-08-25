//T macro:expect-failure
//T check:lvalue
module test;


enum MEANING_OF_LIFE = 42;

fn addOne(ref a: i32)
{
	a++;
	return;
}

fn main() i32
{
	addOne(ref MEANING_OF_LIFE);
	return 0;
}
