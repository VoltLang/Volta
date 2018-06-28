module main;

fn main() i32
{
	a := new "${5 > 2 ? \"hello\" : \"bar\"}";
	if (a != "hello") {
		return 1;
	}
	return 0;
}
