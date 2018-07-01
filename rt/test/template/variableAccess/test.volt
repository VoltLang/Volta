//T macro:import
module main;

static import get;

enum V = 5;

fn a = mixin get.getV!i32;
fn b = get.getV!i32;

fn main() i32
{
	if (a() != V) {
		return 1;
	}
	if (b() != get.pubV) {
		return 2;
	}
	return a() + b() - 15;
}
