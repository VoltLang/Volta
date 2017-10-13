//T requires:sysvamd64
module test;

extern (C) fn functhing(str: string, ref idx: i32)
{
	idx += cast(i32)str.length;
}

fn main() i32
{
	idx: i32 = 12;
	functhing("hello world", ref idx);
	return idx - 23;
}
