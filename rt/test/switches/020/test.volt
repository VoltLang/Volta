//T compiles:yes
//T retval:42
module test;


int main()
{
	switch("get") {
	case "get", "remove":
		return 42;
	default:
		return 4;
	}
}
