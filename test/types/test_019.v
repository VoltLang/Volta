//T compiles:yes
//T retval:42
// Alias test.
module test_019;

// Alias other alias
alias foo = int;
alias bar = foo;



// Alias classes
class ClazzFoo
{
	this()
	{
		return;
	}

	bar g;
}

alias ClazzBar = ClazzFoo;


// Alias functions.
int funcFoo(int v)
{
	auto b = new ClazzBar();
	b.g = 20;

	return b.g + v;
}

alias funcBar = funcFoo;



int main()
{
	return funcBar(22);
}
