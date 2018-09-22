//T macro:expect-failure
//T check:unidentified identifier 'init'
module test;

struct S
{
	x: i32;
}

fn main() i32
{
	s := S.init;
	return s.x;
}