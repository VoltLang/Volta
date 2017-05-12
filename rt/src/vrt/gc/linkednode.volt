// Copyright © 2017, Bernard Helyer
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/**
 * Doubly linked list for GigaMan to track extents allocated without the extent tree.
 */
module vrt.gc.linkednode;

import vrt.gc.rbtree;

struct LinkedNode
{
public:
	prev: LinkedNode*;
	next: LinkedNode*;
}

/**
 * A union of LinkedNode and Node. The code that deals with their extents
 * knows which one they want, so there's no need to distinguish between them
 * on the extent itself.
 */
union UnionNode
{
	linked: LinkedNode;
	tree: Node;
}
