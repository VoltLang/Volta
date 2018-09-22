module test;

fn main() i32
{
	i: i32;
	p := &i;
	p = (i32*).default;
	return cast(i32)p;
}
