//T compiles:yes
//T retval:3
module test;

int add(string stack)
{
	int foo() {
		if (stack.length > 0) {
			return 3;
		}
		return 2;
	}
	return foo();
}

int main()
{
	return add("dulce et decorum est");
}
