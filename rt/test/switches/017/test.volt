//T compiles:yes
//T retval:5
module test;

enum Enum {
	v0,
	v1
}

int foo(Enum e)
{
	int ret = 0;

	final switch (e) {
	case Enum.v0:
		if (ret == 0) {
			ret = 5;
			goto case;
		}
		ret = 6;
		goto case;
	case Enum.v1:
		break;
	}
	return ret;
}


int main()
{
	return foo(Enum.v0);
}
