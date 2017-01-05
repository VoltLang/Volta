//T default:no
//T macro:expect-failure
//T check:scope through assignment
// MI to global scope assignment.
module test;

global sip: scope(i32*) = null;

fn main() i32
{
	return 0;
}
