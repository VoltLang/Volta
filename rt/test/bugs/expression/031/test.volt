module test;


fn main() i32
{
	foo: string = "four";
	ret: i32;

	foreach(i, c: char; foo) {
		ret = cast(i32)i + 1;
	}
	return ret - 4;
}
