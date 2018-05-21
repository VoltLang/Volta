//T macro:expect-failure
//T check:statement not reached
module test;

fn main() i32
{
	do {
	} while(true);
	return 0;
}
