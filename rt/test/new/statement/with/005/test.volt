module test;


enum Enum
{
	Foo = 11,
}

fn main() i32
{
	switch (4) with (Enum) {
	case 4:
		switch (Foo) {
		//   vvv This Foo fails, the switch and return are okay.
		case Foo:
			return Foo - 11;
		default:
		}
		break;
	default:
	}
	return 42;
}
