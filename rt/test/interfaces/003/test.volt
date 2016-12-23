//T compiles:yes
//T retval:6
module test;

interface A
{
	int getNumber();
}

interface B
{
	int getThree();
}

interface X
{
	int getOne();
}

class C : A
{
	override int getNumber()
	{
		return 1;
	}
}

class D : C, X, B
{
	override int getNumber()
	{
		return 2;
	}

	override int getThree()
	{
		return 3;
	}

	override int getOne()
	{
		return 1;
	}
}

int pointlessMiddleman(A a, B b, X x)
{
	return a.getNumber() + b.getThree() + x.getOne();
}

int main()
{
	auto d = new D();
	return pointlessMiddleman(d, d, d);
}

