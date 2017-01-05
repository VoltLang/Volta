module test;


// immutable somehow explodes.
global arr: immutable(u8)[3];

fn main() i32
{
	return arr[0];
}
