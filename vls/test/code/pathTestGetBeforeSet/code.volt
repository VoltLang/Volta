//T macro:code
module code;

import vls.util.pathTree;

fn main() i32
{
	tree: PathTree;
	if (tree.get(["foo"]) !is null) {
		return 1;
	}
	return 0;
}
