module test;

import vrt.gc.rbtree;
import vrt.ext.stdc;

struct IntegerNode
{
	node: Node;
	val: i32;
	sval: string;

	global fn create(n: i32, ns: string) Node*
	{
		_in := new IntegerNode;
		assert(_in.node.children[0].isBlack);
		assert(_in.node.children[1].isBlack);
		_in.val = n;
		_in.sval = ns;
		return cast(Node*)_in;
	}
}

fn printTree(n: Node*, ref buf: char[])
{
	node := cast(IntegerNode*)n;
	if (node is null) {
		return;
	}
	if (node.node.left.node is null &&
		node.node.right.node is null) {
		buf ~= "(" ~ node.sval ~ ")";
		return;
	}

	nn := node.node;
	b := nn.left.isBlack;
	if (b) {
		buf ~= "(" ~ node.sval ~ " l";
	} else {
		buf ~= "(" ~ node.sval ~ " L";
	}
	printTree(node.node.left.node, ref buf);
	if (node.node.right.isBlack) {
		buf ~= " r";
	} else {
		buf ~= " R";
	}
	printTree(node.node.right.node, ref buf);
	buf ~= ")";
}

fn main() i32
{
	RBTree tree;

	fn comp(aa: Node*, bb: Node*) i32
	{
		a := cast(IntegerNode*)aa;
		b := cast(IntegerNode*)bb;
		if (a is null || b is null) {
			assert(false);
		}
		if (a.val == b.val) {
			return 0;
		} else if (a.val < b.val) {
			return -1;
		} else {
			return 1;
		}
	}

	fn treestring() string
	{
		char[] buf;
		buf ~= "root";
		printTree(tree.root, ref buf);
		return cast(string)new buf[..];
	}

	tree.insert(IntegerNode.create(2, "2"), comp);
	str := treestring();
	if (str != "root(2)") {
		return 1;
	}

	tree.insert(IntegerNode.create(1, "1"), comp);
	str = treestring();
	if (str != "root(2 L(1) r)") {
		return 2;
	}

	tree.insert(IntegerNode.create(4, "4"), comp);
	str = treestring();
	if (str != "root(2 L(1) R(4))") {
	/* This is what most algorithms result in. However,
	 * two black children and a black root doesn't violate any
	 * property of an RBTree, so `root(2 l(1) r(4))` is valid
	 * too.
	 */
	//	return 3;
	}

	tree.insert(IntegerNode.create(5, "5"), comp);
	str = treestring();
	if (str != "root(2 l(1) r(4 l R(5)))") {
		return 4;
	}

	tree.insert(IntegerNode.create(9, "9"), comp);
	str = treestring();
	if (str != "root(2 l(1) r(5 L(4) R(9)))") {
		return 5;
	}

	tree.insert(IntegerNode.create(3, "3"), comp);
	str = treestring();
	if (str != "root(2 l(1) R(5 l(4 L(3) r) r(9)))") {
		return 6;
	}

	tree.insert(IntegerNode.create(6, "6"), comp);
	str = treestring();
	if (str != "root(2 l(1) R(5 l(4 L(3) r) r(9 L(6) r)))") {
		return 7;
	}

	tree.insert(IntegerNode.create(7, "7"), comp);
	str = treestring();
	correctstr := "root(2 l(1) R(5 l(4 L(3) r) r(7 L(6) R(9))))";
	return str == correctstr ? 0 : 1;
}

