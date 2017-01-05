module test;


// The array literal gets the wrong type and turn into a int[].
// Probably the typer overriding the type, which it shouldn't.
global arr: u8[] = [
	0x01, 0x02, 0x03
];

fn main() i32
{
	return arr[1] - 2;
}
