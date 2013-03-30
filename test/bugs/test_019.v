//T compiles:yes
//T retval:42
// Unresolved aliases.
module test_019;


// If not used these the inner most useage of foo is not resolved.
alias foo = int;
alias bar = void function(foo);

int main()
{
	return 42;
}
