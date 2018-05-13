module main;

enum Enum
{
	DeclarationA = "hello",
	DeclarationB = "gello",
}

fn main() i32
{
	str := "hello";
	switch (str) {
	case Enum.DeclarationA:
		return 0;
	default:
		return 1;
	}
}

