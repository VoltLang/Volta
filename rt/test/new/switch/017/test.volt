module test;

enum Enum
{
	v0,
	v1
}

fn foo(e: Enum) i32
{
	ret: i32 = 0;

	final switch (e) {
	case Enum.v0:
		if (ret == 0) {
			ret = 1;
			goto case;
		}
		ret = 6;
		goto case;
	case Enum.v1:
		ret--;
		break;
	}
	return ret;
}

fn main() i32
{
	return foo(Enum.v0);
}
