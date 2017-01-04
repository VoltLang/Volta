//T default:no
//T macro:expect-failure
// Ensure for declarations don't leak.
module test;


fn main() i32
{
	for (x: i32 = 0; x < 10; x++) {}
	return x;
}

