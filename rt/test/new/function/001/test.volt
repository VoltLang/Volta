module test;

fn hitotu(out i: i32)
{
	i = 15;
}

fn futatu(ref i: i32)
{
	i += 2;
}

fn main() i32
{
	i: i32;
	hitotu(out i);
	futatu(ref i);
	return i - 17;
}

