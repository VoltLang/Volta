//T compiles:yes
//T retval:3
module test;

class Base {}
class Sub : Base {}

void foo(int) {}
void foo(Base) {}

void func(out Sub sub)
{
	foo(sub);
}

int main()
{
	return 3;
}
