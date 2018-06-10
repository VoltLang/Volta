//T macro:expect-failure
//T check:parameter name cannot be the same
module main;

enum Type {
	Floor,
	Wall,
}

struct Tile {
	type: i32;
}

fn main() i32 {
	return 0;
}

fn are!(Type: Type)(surrounding: Tile*[], indices: i32[]...) bool {
	foreach (i; indices) {
		if (surrounding[i].type != Type) {
			return false;
		}
	}
	return true;
}

fn areWalls  = mixin are!0;
fn areFloors = mixin are!1;
