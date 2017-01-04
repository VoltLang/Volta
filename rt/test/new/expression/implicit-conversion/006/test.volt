// scope with MI to non scope.
module test;


fn main() i32
{
	si: scope(i32) = 28;
	i: i32 = si;
	return i - 28;
}
