// non-MI to scope assignment.
module test;

fn main() i32
{
	i: i32 = 17;
	si: scope(i32) = i;
	return si - 17;
}
