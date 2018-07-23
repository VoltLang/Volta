module main;

fn getStaticArray() i32[3]
{
	arr: i32[3];
	arr[0] = 1; arr[1] = 3; arr[2] = 4;
	return arr;
}

fn main() i32
{
	cslice := getStaticArray()[1 .. 3];
	if (cslice.length != 2 || cslice[0] != 3 || cslice[1] != 4) {
		return 1;
	}
	zero := 0;
	dslice := getStaticArray()[zero .. (cslice[1] - cslice[0])];
	if (dslice.length != 1 || dslice[0] != 1) {
		return 2;
	}
	slice := getStaticArray()[..];
	return ((slice[0] + slice[1]) * slice[2]) - 16;
}
