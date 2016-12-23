//T compiles:no
// Alias circular dependency test.
module test;


alias foo = bar;
alias bar = foo;

int main()
{
	foo t;
	return 42;
}
