//T compiles:no
// Alias circular dependency test.
module test_020;

alias foo = bar;
alias bar = foo;

int main()
{
	foo t;
	return 42;
}
