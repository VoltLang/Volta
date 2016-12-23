//T compiles:yes
//T retval:1
module test;

int main() {
	return cast(int) typeid(scope void delegate(int)).args.length;
}

