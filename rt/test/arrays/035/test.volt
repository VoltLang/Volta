module test;


fn main() i32
{
	elements: i32[4];
	foreach (i, ref e; elements) {
		e = 42;
	}

	return (elements[3] == 42) ? 0 : 1;
}
