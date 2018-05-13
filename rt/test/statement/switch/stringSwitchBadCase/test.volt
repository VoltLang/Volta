//T macro:expect-failure
//T check:cannot implicitly convert
module main;

enum Enum
{
	DeclarationA,
	DeclarationB
}

fn main() i32
{
	str := "hello";
	switch (str) {
	case 0:
		return 0;
	default:
		return 1;
	}
}

