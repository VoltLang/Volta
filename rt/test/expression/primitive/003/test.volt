//T default:no
//T macro:expect-failure
//T check:neither field, nor property
// Ensure that instances can't be checked for types.
module test;

fn main() i32
{
	flibber: i32;
	return flibber.min;
}
