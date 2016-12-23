module test;

import vrt.gc.rbtree;

fn main() i32
{
	fn comp(aptr: Node*, bptr: Node*) i32 {
		aa := cast(size_t)aptr;
		bb := cast(size_t)bptr;
		if (aa > bb) {
			return 1;
		} else if (aa < bb) {
			return -1;
		} else {
			return 0;
		}
	}

	a := new Node;
	b := new Node;
	c := new Node;

	RBTree tree;
	tree.insert(a, comp);
	tree.insert(b, comp);
	tree.insert(c, comp);

	fn atest(n: Node*) i32 { return comp(a, n); }
	fn btest(n: Node*) i32 { return comp(b, n); }
	fn ctest(n: Node*) i32 { return comp(c, n); }

	if (tree.get(atest) !is a ||
	    tree.get(btest) !is b ||
	    tree.get(ctest) !is c) {
		return 1;
	}

	return 0;
}
