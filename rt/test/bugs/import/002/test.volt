//T macro:import
module b;

static import a;

fn main() i32
{
	return a.bork(1) - 1;
}
