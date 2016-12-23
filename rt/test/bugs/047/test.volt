//T compiles:yes
//T retval:4
module test;

alias foo = int;

int main()
{
	return cast(int) typeid(foo).size;
}

