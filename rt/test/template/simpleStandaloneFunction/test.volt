module main;

fn add!(T)(a: T, b: T) T
{
	return a + b;
}

fn addInteger = mixin add!i32;
fn addFloating = mixin add!f64;

fn main() i32
{
	if (addInteger(3, 1) != 4 || addFloating(3.0, 0.6) <= 3.5) {
		return 1;
	}
	return 0;
}
