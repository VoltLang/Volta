//T compiles:yes
//T retval:6
module test;

class A
{
	int x() { return 6; }
}

class C : A
{
}

class B : A
{
}

class D : B
{
}

int main(string[] args)
{
	auto c = new C();
	auto d = new D();
	A a = args.length > 1 ? c : d;
	return a.x();
}
