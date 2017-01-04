module test;

fn x() u8
{
	return cast(u8)261;
}

fn main() i32
{
	y: i32 = #run x();
	return y - 5;
}
