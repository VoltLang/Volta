// Alias test.
module test;


// Alias other alias
alias foo = i32;
alias bar = foo;

// Alias classes
class ClazzFoo
{
	this()
	{
	}

	g: bar;
}

alias ClazzBar = ClazzFoo;


// Alias functions.
fn funcFoo(v: i32) i32
{
	b := new ClazzBar();
	b.g = 20;

	return b.g + v;
}

alias funcBar = funcFoo;


fn main() i32
{
	return funcBar(22) - 42;
}
