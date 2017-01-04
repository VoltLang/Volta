module test;


fn main() i32
{
	str := "foo".ptr;
	return str[0] == 'f' ? 0 : 1;
}
