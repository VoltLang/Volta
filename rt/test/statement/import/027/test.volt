//T macro:import
module test;

static import test2;
static import foo.bar.baz;

fn main() i32
{
	test2.setX();
	return foo.bar.baz.x - 12;
}

