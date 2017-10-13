//T requires:sysvamd64
module test;

extern (C) fn Func(chars: char[][]) i32
{
	if (chars[0][2] == 'h' && chars[0][4] == 'n') {
		return 0;
	} else {
		return 1;
	}
}

fn main() i32
{
	msgs: char[][1];
	msgs[0] = cast(char[])"unhandled case";
	return Func(cast(char[][])msgs);
}
