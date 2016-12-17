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
	d := new Node;

	RBTree tree;
	tree.insert(a, comp);
	tree.insert(b, comp);
	tree.insert(c, comp);
	// d pointedly absent

	fn atest(n: Node*) bool { return n is a; }
	fn btest(n: Node*) bool { return n is b; }
	fn ctest(n: Node*) bool { return n is c; }
	fn dtest(n: Node*) bool { return n is d; }

	if (tree.find(atest) !is a ||
	    tree.find(btest) !is b ||
	    tree.find(ctest) !is c ||
		tree.find(dtest) !is null) {
		return 1;
	}

	return 0;
}
