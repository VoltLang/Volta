//T compiles:yes
//T retval:42
module test;

int main()
{
	void foo() { return; }
	return typeid(foo).mangledName == typeid(scope void delegate()).mangledName ? 42 : 0;
}
