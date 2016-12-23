//T compiles:no
module test;

class Base {}

class Sub : Base {}

Base[] func()
{
	return null;
}

int main()
{
	// This ends up in the backend and not being caught earlier.
	Base[] = cast(Base)func();
	return 9;
}
