//T compiles:yes
//T retval:42
module test;


int f(string str)
{
	switch(str) {
	case "another":
	case "thing":
	case "remove":
	case "f32":
		return 21;
	case "dst":
		return 21;
	default:
	}
		return 4;
}

int main()
{
	return f("dst") + f("remove");
}
