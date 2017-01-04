//T default:no
//T macro:expect-failure
//T check:cannot implicitly convert
// scope with MI to non scope.
module test;


fn main() i32
{
	sip: scope(i32*);
	ip: i32* = sip;
	return 0;
}
