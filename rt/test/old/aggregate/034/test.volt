//T compiles:yes
//T retval:3
module test;

class Parent
{
	int f() { return 1; }
}

class Child : Parent
{
	override int f() { return 2; }
}

class GrandChild : Child
{
	override int f() { return 3; }
}

// Testing function, takes a child not grandchild.
int func(Child c)
{
	// This call doesn't get dispatched.
	return c.f();
}

int main()
{
	// Create the grandchild.
	auto c = new GrandChild();
	return func(c);
}
