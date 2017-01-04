module test;

fn main() i32
{
	buf := new char[](1);
	buf[0] = 'a';
	str := new string(buf);
	buf[0] = 'b';
	return str[0] == 'a' ? 0 : 4;
}

