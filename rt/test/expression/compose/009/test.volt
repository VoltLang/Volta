module test;

fn main() i32
{
	val := new "${ [ \"a\" : 12 ] }";
	return val == `["a":12]` ? 0 : 1;
}