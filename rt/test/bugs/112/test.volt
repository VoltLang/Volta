//T compiles:yes
//T retval:0
module test;


class Clazz
{

}

struct My
{
	int foo;
	int* ptr;
	int[] arr;
	void delegate() dgt;
	void function() func;
	Clazz clazz;
}

int main()
{
	My my;
	my.foo = 42;
	my = My.init;

	return my.foo;
}
