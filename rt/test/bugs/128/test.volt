//T compiles:yes
//T retval:42
module test;


alias Alias = int;

int main()
{
	foo : Alias;
	foo = 42; 
	return foo;
}

