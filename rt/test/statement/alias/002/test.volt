//T macro:expect-failure
//T check:circular dependency detected
// Alias circular dependency test.
module test;


alias foo = bar;
alias bar = foo;

fn main() i32
{
	t: foo;
	return 0;
}
