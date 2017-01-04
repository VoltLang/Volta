// Unresolved aliases.
module test;


// If not used these the inner most useage of foo is not resolved.
alias foo = i32;
alias bar = fn(foo);

fn main() i32
{
	return 0;
}
