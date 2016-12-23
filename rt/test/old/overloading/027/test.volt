//T compiles:yes
//T retval:0
module test;

fn func(f: scope const(char)[], ...) i32
{
	return 0;
}

// If this function is commented out the test passes.
fn func(sink: scope dg(scope const(char)[]), f: scope const(char)[], ...) i32
{
	return 1;
}

fn main() i32
{
	// Volta crashes if there is only one argument to the function
	func("34");

	return func("blarg %s", 4);
}
