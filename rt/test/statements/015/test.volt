//T compiles:yes
//T retval:11
module test;


enum Enum
{
	Foo = 11,
}

int main()
{
	switch (4) with (Enum) {
	case 4:
		switch (Foo) {
		//   vvv This Foo fails, the switch and return are okay.
		case Foo:
			return Foo;
		default:
		}
		break;
	default:
	}
	return 42;
}
