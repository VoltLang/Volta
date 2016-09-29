// Copyright © 2016, Amaury Séchet.  All rights reserved.
// Copyright © 2016, Bernard Helyer.  All rights reserved.
// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/**
 * RBTree implementation for the GC.
 */
module vrt.gc.rbtree;

import vrt.gc.util : gcAssert;

alias Colour = bool;
enum Black = false;
enum Red = true;

/**
 * Embeddable Node for the RBTree.
 */
struct Node
{
private:
	children: Link[2];


public:
	@property fn left() Link*
	{
		return &children[0];
	}

	@property fn left(l: Link)
	{
		children[0] = l;
	}

	@property fn right(l: Link)
	{
		children[1] = l;
	}

	@property fn right() Link*
	{
		return &children[1];
	}

	fn visit(func: RBTree.VisitDg)
	{
		if (l := children[0].node) {
			l.visit(func);
		}

		func(&this);

		if (r := children[1].node) {
			r.visit(func);
		}
	}
}

/**
 * Wrapping a pointer and red black bit, link from one Node to another.
 */
struct Link
{
private:
	enum size_t ColourShift = 0;
	enum size_t ColourMask = 0x01;  // TODO: 1 << ColourShift
	enum size_t NodeMask = 1; // TODO:  ColourMask

	/// A tagged pointer, if unlucky GC will not follow.
	mChild: size_t;


public:
	global fn build(n: Node*, c: Colour) Link
	{
		gcAssert(c == Black || n !is null);
		l: Link;
		l.mChild = cast(size_t)n | c;
		gcAssert(n is l.node);
		return l;
	}

	fn getAs(c: Colour) Link
	{
		if (c == Black) {
			return getAsBlack();
		} else {
			return getAsRed();
		}
	}

	fn getAsBlack() Link
	{
		return Link.build(node, Black);
	}

	fn getAsRed() Link
	{
		gcAssert(node !is null);
		return Link.build(node, Red);
	}

	@property fn node() Node*
	{
		return cast(Node*)(mChild & ~NodeMask);
	}

	@property fn colour() Colour
	{
		return cast(Colour)(mChild & ColourMask);
	}

	@property fn isRed() bool
	{
		return colour == Red;
	}

	@property fn isBlack() bool
	{
		return colour == Black;
	}

	@property fn isLeaf() bool
	{
		return mChild == 0;
	}

	@property fn left() Link*
	{
		return node.left;
	}

	@property fn right() Link*
	{
		return node.right;
	}

	@property fn left(l: Link)
	{
		node.left = l;
	}

	@property fn right(l: Link)
	{
		node.right = l;
	}

	fn getChild(cmp: bool) Link*
	{
		if (!cmp) {
			return left;
		} else {
			return right;
		}
	}

	/**
	 * Rotate the tree and return the new root.
	 * The tree turns clockwise if cmp is true.
	 * Otherwise, it turns counterclockwise.
	 */
	fn rotate(cmp: bool) Link
	{
		x := *getChild(!cmp);
		*getChild(!cmp) = *x.getChild(cmp);
		*x.getChild(cmp) = this;
		return x;
	}
}

struct Path
{
private:
	enum size_t ColourShift = 0;
	enum size_t ColourMask = 0x01;  // TODO: 1 << ColourShift
	enum size_t CmpShift = 1;
	enum size_t CmpMask = 0x02;  // TODO: 1 << CmpShift
	enum size_t NodeMask = 0x03;  // TODO: CmpMask | ColourMask;

	/// A tagged pointer, if unlucky GC will not follow.
	mChild: size_t;


public:
	global fn build(l: Link, c: bool) Path
	{
		path: Path;
		path.mChild = l.mChild | (c << CmpShift);
		return path;
	}

	@property fn colour() Colour
	{
		return cast(Colour)(mChild & ColourMask);
	}

	@property fn isRed() bool
	{
		return colour == Red;
	}

	@property fn isBlack() bool
	{
		return colour == Black;
	}

	@property fn cmp() bool
	{
		return cast(bool)((mChild & CmpMask) >> CmpShift);
	}

	@property fn node() Node*
	{
		return cast(Node*)(mChild & ~NodeMask);
	}

	@property fn link() Link
	{
		return Link.build(node, isRed);
	}

	fn getWithLink(l: Link) Path
	{
		return Path.build(l, cmp);
	}

	fn getWithCmp(c: bool) Path
	{
		return Path.build(link, c);
	}

	fn getChild(c: bool) Link*
	{
		if (!c) {
			return node.left;
		} else {
			return node.right;
		}
	}
}

/**
 * The tree's root object.
 * This doesn't allocate any nodes, that is handled by the client code.
 * Test and compare delegates are user defined.
 */
struct RBTree
{
public:
	alias TestDg = scope dg (Node*) int;
	alias CompDg = scope dg (Node*, Node*) int;
	alias VisitDg = scope dg (Node*);


private:
	root: Node*;


public:
	fn get(test: TestDg) Node*
	{
		n := root;

		while (n !is null) {
			cmp := test(n);
			// We have a perfect match.
			if (cmp == 0) {
				return n;
			}

			n = n.children[cmp > 0].node;
		}

		return null;
	}

	/**
	 * Visit each node of the tree and call func.
	 * The given function may not add or remove elements to the tree.
	 */
	fn visit(func: VisitDg)
	{
		if (root !is null) {
			root.visit(func);
		}
	}

	fn insert(n: Node*, compare: CompDg)
	{
		// rbtree's depth is ln(n) which is at most 8 * size_t.sizeof.
		// Each tree node that N.sizeof size, so we can remove ln(N.sizeof).
		// But a branch can be at most 2* longer than the shortest one.
//		path: Path[16 * typeid(size_t).size  - lg2floor(N.sizeof)] = void;
		path: Path[128];
		stackp := path.ptr;

		// Let's make sure this is a child node.
		n.left = Link.build(null, Black);
		n.right = Link.build(null, Black);

		// Root is always black.
		link := Link.build(root, Black);
		while (!link.isLeaf) {
			diff := compare(n, link.node);
			gcAssert(diff != 0);

			cmp := diff > 0;
			*stackp = Path.build(link, cmp);
			gcAssert(link.colour == stackp.colour);

			stackp++;
			link = *link.getChild(cmp);
		}

		// The tree only has a root.
		if (stackp is path.ptr) {
			root = n;
			return;
		}

		// Inserted node is always red.
		*stackp = Path.build(Link.build(n, Red), false);
		gcAssert(stackp.isRed);

		// Now we found an insertion point, let's fix the tree.
		for (stackp--; stackp !is (&path[0] - 1); stackp--) {
			link = stackp.link;
			cmp := stackp.cmp;

			child := stackp[1].link;
			*link.getChild(cmp) = child;
			if (child.isBlack) {
				break;
			}

			if (link.isRed) {
				continue;
			}

			sibling := link.getChild(!cmp);
			if (sibling.isRed) {
				gcAssert(link.isBlack);
				gcAssert(link.left.isRed && link.right.isRed);

				/*
				 *     B          Br
				 *    / \   =>   / \
				 *   R   R      Rb  Rb
				 */
				link.left = link.left.getAsBlack();
				link.right = link.right.getAsBlack();
				*stackp = stackp.getWithLink(link.getAsRed());
				continue;
			}

			line := child.getChild(cmp);
			if (line.isBlack) {
				if (child.getChild(!cmp).isBlack) {
					// Our red child has 2 black children, we are good.
					break;
				}

				/**
				 * We transform The zigzag case into the line case.
				 *
				 *                 B
				 *     B          / \
				 *    / \        B   R
				 *   B   R   =>       \
				 *      / \            R
				 *     R   B            \
				 *                       B
				 */
				gcAssert(child.getChild(!cmp).isRed);
				child = child.rotate(cmp);
			}

			/**
			 *     B            Rb
			 *    / \          / \
			 *   B   R   =>   Br  R
			 *      / \      / \
			 *     B   R    B   B
			 */
			*link.getChild(cmp) = child.getAsBlack();
			link = link.getAsRed();
			*stackp = stackp.getWithLink(link.rotate(!cmp));
		}

		root = path[0].node;
	}

	fn remove(n: Node*, compare: CompDg)
	{
		gcAssert(n !is null);
		removed := extract(n, compare);
		gcAssert(removed !is null);
		gcAssert(n is removed);
	}

	fn extractAny(compare: CompDg) Node*
	{
		return extract(root, compare);
	}

	fn extract(n: Node*, compare: CompDg) Node*
	{
		// rbtree's depth is ln(n) which is at most 8 * size_t.sizeof.
		// Each tree node that N.sizeof size, so we can remove ln(N.sizeof).
		// But a branch can be at most 2* longer than the shortest one.
		//Path[16 * size_t.sizeof - lg2floor(N.sizeof)] path = void;
		path : Path[128];
		stackp := path.ptr; // TODO: use .ptr when available.

		// Root is always black.
		link := Link.build(root, Black);
		rn := root;
		while (rn !is null) {
			diff := compare(n, rn);

			// We found our node !
			if (diff == 0) {
				break;
			}

			cmp := diff > 0;
			*stackp = Path.build(link, cmp);

			stackp++;
			link = *link.getChild(cmp);
			rn = link.node;
		}

		if (rn is null) {
			return null;
		}

		// Now we look for a succesor.
		*stackp = Path.build(link, true);
		removep := stackp;
		removed := link;

		/*
		 * We find a replacing node by going one to the right
		 * and then as far as possible to the left. That way
		 * we get the next node in the tree and its ordering
		 * will be valid.
		 */
		link = *removed.right;
		while (!link.isLeaf) {
			stackp++;
			*stackp = Path.build(link, false);
			link = *link.left;
		}

		link = stackp.link;

		if (stackp is removep) {
			// The node we remove has no successor.
			*stackp = stackp.getWithLink(*link.left);
		} else {
			/*
			 * Swap node to be deleted with its successor
			 * but not the colour, so we keep tree colour
			 * constraint in place.
			 */
			rcolour := removed.colour;

			removed = removed.getAs(link.colour);
			*stackp = stackp.getWithLink(*link.right);

			link = link.getAs(rcolour);
			link.left = *removed.left;

			/*
			 * If the successor is the right child of the
			 * node we want to delete, this is incorrect.
			 * However, it doesn't matter, as it is going
			 * to be fixed during pruning.
			 */
			link.right = *removed.right;

			// NB: We don't clean the node to be removed.
			// We simply splice it out.
			*removep = removep.getWithLink(link);
		}

		// If we are not at the root, fix the parent.
		if (removep !is path.ptr) {
			*removep[-1].getChild(removep[-1].cmp) = removep.link;
		}

		// Removing a red node requires no fix-ups.
		if (removed.isRed) {
			*stackp[-1].getChild(stackp[-1].cmp) = Link.build(null, Black);

			// Update root and exit
			root = path[0].node;
			return rn;
		}

		for (stackp--; stackp !is (&path[0] - 1); stackp--) {
			link = stackp.link;
			cmp := stackp.cmp;

			child := stackp[1].link;
			if (child.isRed) {
				// If the double black is on a red node, recolour.
				*link.getChild(cmp) = child.getAs(Black);
				break;
			}

			*link.getChild(cmp) = child;

			/*
			 * b = changed to black
			 * r = changed to red
			 * // = double black path
			 *
			 * We rotate and recolour to find ourselves in a case
			 * where sibling is black one level below. Because the
			 * new root will be red, zigzag case will bubble up
			 * with a red node, which is going to terminate.
			 *
			 *            Rb
			 *   B         \
			 *  / \\   =>   Br  <- new link
			 * R    B        \\
			 *                 B
			 */
			sibling := *link.getChild(!cmp);
			if (sibling.isRed) {
				gcAssert(link.isBlack);

				link = link.getAs(Red);
				parent := link.rotate(cmp);
				*stackp = stackp.getWithLink(parent.getAs(Black));

				// As we are going down one level, make sure we fix the parent.
				if (stackp !is path.ptr) {
					*stackp[-1].getChild(stackp[-1].cmp) = stackp.link;
				}

				stackp++;

				// Fake landing one level below.
				// NB: We don't need to fake cmp.
				*stackp = stackp.getWithLink(link);
				sibling = *link.getChild(!cmp);
			}

			line := *sibling.getChild(!cmp);

			if (line.isBlack) {
				if (sibling.getChild(cmp).isBlack) {
					/*
					 * b = changed to black
					 * r = changed to red
					 * // = double black path
					 *
					 * We recolour the sibling to push the double
					 * black one level up.
					 *
					 *     X           (X)
					 *    / \\         / \
					 *   B    B  =>   Br  B
					 *  / \          / \
					 * B   B        B   B
					 */
					*link.getChild(!cmp) = sibling.getAs(Red);
					continue;
				}

				/*
				 * b = changed to black
				 * r = changed to red
				 * // = double black path
				 *
				 * We rotate the zigzag to be in the line case.
				 *
				 *                   X
				 *     X            / \\
				 *    / \\         Rb   B
				 *   B    B  =>   /
				 *  / \          Br
				 * B   R        /
				 *             B
				 */
				line = sibling.getAsRed();
				sibling = line.rotate(!cmp);
				sibling = sibling.getAsBlack();
				*link.getChild(!cmp) = sibling;
			}

			/*
			 * b = changed to black
			 * x = changed to x's original colour
			 * // = double black path
			 *
			 *     X           Bx
			 *    / \\        / \
			 *   B    B  =>  Rb  Xb
			 *  / \             / \
			 * R   Y           Y   B
			 */
			l := link.getAs(Black);
			l = l.rotate(cmp);
			*l.getChild(!cmp) = line.getAs(Black);

			// If we are the root, we are done.
			if (stackp is path.ptr) {
				root = l.node;
				return rn;
			}

			*stackp[-1].getChild(stackp[-1].cmp) = l.getAs(link.colour);
			break;
		}

		// Update root and exit.
		root = path[0].node;
		return rn;
	}
}
