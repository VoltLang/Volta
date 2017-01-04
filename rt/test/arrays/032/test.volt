module test;

fn main() i32
{
	aa := new char[](1);
	aa[0] = 'a';
	bb := new char[](1);
	bb[0] = 'a';
	a := [aa];
	b := [bb];
	if (a != b) {
		return 1;
	}
	return 0;
}

