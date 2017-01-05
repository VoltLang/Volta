module test;

fn main() i32
{
	// From D's static
	global fn foo() i32 {
		return 42;
	}

	return foo() - 42;
}
