//T compiles:no
module test;

class Derived
{
}

int count(object.Object[] objects...)
{
	return cast(int) objects.length; 
}

int main()
{
	return count([new Derived()]);
}
