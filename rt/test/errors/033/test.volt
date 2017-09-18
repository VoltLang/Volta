//T macro:expect-failure
//T check:test.volt:7
module test;

enum Count : u32 = 8u * 1024u * 1024u /*;*/

fn main() i32
{
	return 0;
}