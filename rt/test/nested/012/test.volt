module test;

fn add(stack: string) i32
{
	fn foo() i32
	{
		if (stack.length > 0) {
			return 3;
		}
		return 2;
	}
	return foo();
}

fn main() i32
{
	return add("dulce et decorum est") - 3;
}
