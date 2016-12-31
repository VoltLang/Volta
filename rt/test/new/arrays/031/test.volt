module test;

global this()
{
	x = 2;
}

static x: i32;
static a: string[] = ["hi"];
static b: string[] = ["hi"];

fn main() i32
{
	return (x + cast(int)a[0].length + cast(int)b[0].length == 6) ? 0 : 1;
}
