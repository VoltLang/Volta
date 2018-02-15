//T macro:code
module code;

import vls.util.pathTree;

fn main() i32
{
	tree: PathTree;
	tree.set("foo", "hello");
	tree.set("foo.bar", "world");
	if (tree.get(["foo"]) != "hello") {
		return 1;
	}
	if (tree.get(["foo", "bar"]) != "world") {
		return 1;
	}
	if (tree.get(["food", "bar"]) !is null) {
		return 1;
	}
	if (tree.get(["foo", "baz"]) != "hello") {
		return 1;
	}
	if (tree.get(["foo", "bar", "baz"]) != "world") {
		return 1;
	}
	return 0;
}
