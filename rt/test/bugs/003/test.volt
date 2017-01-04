//T default:no
//T macro:expect-failure
//T check:lvalue
// LValue checking is broken.
module test;


fn main() i32
{
	f: i32[] = new i32[](4);
	t := &f[0 .. 5]; // Array slice is not a LValue

	return 0;
}

