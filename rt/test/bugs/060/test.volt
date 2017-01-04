module test;

fn wf(strings: string[]...) i32
{
	return cast(i32) strings[0].length;
}

fn wf(x: i32) i32
{
	return 7;
}

fn main() i32
{
	return wf("hello") - 5;
}

