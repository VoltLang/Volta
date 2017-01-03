module test;

// We use a array here to force the type to be different enough
// from the first arg to select the other function, its important
// we should match the other func.
fn bug(i32[]) {}
fn bug(i32, foo: string[]...) { val += 20; }

fn otherBug() {}
fn otherBug(i32, foo: string[]...) { val += 22; }

global val: i32;

fn main() i32
{
	// Its probably easier to fix them in this order.
	// The above order is in the order I found them.
	otherBug(1);

	bug(1);

	return val - 42;
}
