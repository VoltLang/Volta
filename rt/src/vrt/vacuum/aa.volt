// Copyright © 2013, David Herberth.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.vacuum.aa;

static import object;
import core.exception;


// Volts AA (Associative Array) Implementation
// based on a Red-Black-Tree
// http://en.wikipedia.org/wiki/Red%E2%80%93black_tree


private union TreeStore {
	void* ptr;
	ulong unsigned;
	void[] array;
}

// Represents a Node in the Red-Black-Tree
private struct TreeNode
{
	TreeStore key; // long for now, simplest case, no comparison function needed
	TreeStore value;

	bool red; // true if red
	TreeNode* parent;
	TreeNode* left;
	TreeNode* right;
}

// Basically only holds the root-node
private struct RedBlackTree
{
	TreeNode* root;
	size_t length;

	object.TypeInfo value;
	object.TypeInfo key;
	bool isValuePtr;
}


extern(C) void* vrt_aa_new(object.TypeInfo value, object.TypeInfo key)
{
	RedBlackTree* rbt = new RedBlackTree;
	rbt.root = null;
	rbt.value = value;
	rbt.key = key;
	rbt.length = 0;
	rbt.isValuePtr = value.size > typeid(TreeStore).size;
	return cast(void*)rbt;
}

extern(C) size_t vrt_aa_get_length(void* rbtv)
{
	if (rbtv is null) {
		return 0;
	}
	RedBlackTree* rbt = cast(RedBlackTree*)rbtv;
	return rbt.length;
}

private TreeNode* vrt_aa_dup_treenode(TreeNode* tn, TreeNode* parent=null)
{
	if (tn is null) {
		return null;
	}
	auto dup = new TreeNode;
	dup.key = tn.key;
	dup.value = tn.value;
	dup.red = tn.red;
	dup.parent = parent;
	dup.left = vrt_aa_dup_treenode(tn.left, dup);
	dup.right = vrt_aa_dup_treenode(tn.right);
	return dup;
}

extern(C) void* vrt_aa_dup(void* rbtv)
{
	auto rbt = cast(RedBlackTree*)rbtv;
	auto newRbt = cast(RedBlackTree*)vrt_aa_new(rbt.value, rbt.key);
	newRbt.root = vrt_aa_dup_treenode(rbt.root);
	newRbt.length = rbt.length;
	return cast(void*)newRbt;
}

// vrt_aa_get_keyvalue (e.g. vrt_aa_get_pa key == primitive, value == array)
// aa.get("key", null) => vrt_aa_get_primitive(aa, "key", null)

extern(C) ulong vrt_aa_get_pp(void* rbtv, ulong key, ulong _default)
{
	TreeNode* tn = vrt_aa_lookup_node_primitive(rbtv, key);
	if (tn is null) {
		return _default;
	} else {
		return tn.value.unsigned;
	}
}

extern(C) void[] vrt_aa_get_aa(void* rbtv, void[] key, void[] _default)
{
	void[] ret;
	if (vrt_aa_in_array(rbtv, key, cast(void*)&ret)) {
		return ret;
	} else {
		return _default;
	}
}

extern(C) ulong vrt_aa_get_ap(void* rbtv, void[] key, ulong _default)
{
	TreeNode* tn = vrt_aa_lookup_node_array(rbtv, key);
	if (tn is null) {
		return _default;
	} else {
		return tn.value.unsigned;
	}
}

extern(C) void[] vrt_aa_get_pa(void* rbtv, ulong key, void[] _default)
{
	void[] ret;
	if (vrt_aa_in_primitive(rbtv, key, cast(void*) &ret)) {
		return ret;
	} else {
		return _default;
	}
}


private TreeNode* vrt_aa_lookup_node_primitive(void* rbtv, ulong key)
{
	if (rbtv is null) {
		return null;
	}

	RedBlackTree* rbt = cast(RedBlackTree*)rbtv;
	TreeNode* node = rbt.root;

	while (node !is null) {
		if (node.key.unsigned < key) {
			node = node.left;
		} else if (node.key.unsigned > key) {
			node = node.right;
		} else { // we found it!
			return node;
		}
	}

	return null;
}

private TreeNode* vrt_aa_lookup_node_array(void* rbtv, void[] key)
{
	if (rbtv is null) {
		return null;
	}

	RedBlackTree* rbt = cast(RedBlackTree*)rbtv;
	TreeNode* node = rbt.root;

	while (node !is null) {
		int comparison;
		if (node.key.array.length < key.length) {
			comparison = 1; // key.length is longer
		} else if (node.key.array.length > key.length) {
			comparison = -1; // key.length is shorter
		} else {
			comparison = object.vrt_memcmp(node.key.array.ptr, key.ptr, key.length);
		}

		if (comparison < 0) {
			node = node.left;
		} else if (comparison > 0) {
			node = node.right;
		} else { // we found it!
			return node;
		}
	}

	return null;
}

extern(C) bool vrt_aa_in_primitive(void* rbtv, ulong key, void* ret)
{
	if (rbtv is null) {
		return false;
	}

	RedBlackTree* rbt = cast(RedBlackTree*)rbtv;
	TreeNode* node = vrt_aa_lookup_node_primitive(rbtv, key);
	if (node is null) {
		return false;
	}

	if (rbt.isValuePtr) {
		object.__llvm_memcpy(ret, node.value.ptr, rbt.value.size, 0, false);
	} else {
		object.__llvm_memcpy(ret, cast(void*)&(node.value), rbt.value.size, 0, false);
	}
	return true;
}

extern(C) bool vrt_aa_in_array(void* rbtv, void[] key, void* ret)
{
	if (rbtv is null) {
		return false;
	}

	RedBlackTree* rbt = cast(RedBlackTree*)rbtv;
	TreeNode* node = vrt_aa_lookup_node_array(rbtv, key);
	if (node is null) {
		return false;
	}

	if (rbt.isValuePtr) {
		object.__llvm_memcpy(ret, node.value.ptr, rbt.value.size, 0, false);
	} else {
		object.__llvm_memcpy(ret, cast(void*)&(node.value), rbt.value.size, 0, false);
	}
	return true;
}

extern(C) void* vrt_aa_in_binop_array(void* rbtv, void[] key)
{
	if (rbtv is null) {
		return null;
	}

	RedBlackTree* rbt = cast(RedBlackTree*)rbtv;
	TreeNode* tn = vrt_aa_lookup_node_array(rbtv, key);
	if (tn is null) {
		return null;
	}
	if (rbt.isValuePtr) {
		return tn.value.ptr;
	} else {
		return cast(void*)&tn.value;
	}
}

extern(C) void* vrt_aa_in_binop_primitive(void* rbtv, ulong key)
{
	if (rbtv is null) {
		return null;
	}

	RedBlackTree* rbt = cast(RedBlackTree*)rbtv;
	TreeNode* tn = vrt_aa_lookup_node_primitive(rbtv, key);
	if (tn is null) {
		return null;
	}
	if (rbt.isValuePtr) {
		return tn.value.ptr;
	} else {
		return cast(void*)&tn.value;
	}
}

private void vrt_aa_rotate_left(RedBlackTree* rbt, TreeNode* node)
{
	TreeNode* right = node.right;
	vrt_aa_replace_node(rbt, node, right);
	node.right = right.left;
	if (right.left !is null) {
		right.left.parent = node;
	}
	right.left = node;
	node.parent = right;
}

private void vrt_aa_rotate_right(RedBlackTree* rbt, TreeNode* node)
{
	TreeNode* left = node.left;
	vrt_aa_replace_node(rbt, node, left);
	node.left = left.right;
	if (left.right !is null) {
		left.right.parent = node;
	}
	left.right = node;
	node.parent = left;
}

private void vrt_aa_replace_node(RedBlackTree* rbt, TreeNode* old, TreeNode* new_)
{
	if (old is null || old.parent is null) {
		rbt.root = new_;
	} else {
		if (old is old.parent.left) { // we are the parents left node
			old.parent.left = new_;
		} else { // we are the parents right node
			old.parent.right = new_;
		}
	}

	if (new_ !is null) {
		new_.parent = old.parent;
	}
}

extern(C) void vrt_aa_insert_primitive(void* rbtv, ulong key, void* value)
{
	RedBlackTree* rbt = cast(RedBlackTree*)rbtv;
	// Maybe put allocation of a new node into an external function
	TreeNode* inserted_node = new TreeNode;
	inserted_node.key.unsigned = key;
	inserted_node.red = true; // we have to check the rules afterwards and fix the tree!

	if (rbt.isValuePtr) {
		// allocate more memory for value
		void* mem = object.allocDg(rbt.value, 1);
		object.__llvm_memcpy(mem, value, rbt.value.size, 0, false);
		inserted_node.value.ptr = mem;
	} else {
		object.__llvm_memcpy(cast(void*)&(inserted_node.value), value, rbt.value.size, 0, false);
	}

	if (rbt.root is null) {
		rbt.root = inserted_node;
	} else {
		TreeNode* node = rbt.root;

		bool continue_ = true;
		while (continue_) {
			if (node.key.unsigned < key) {
				if (node.left is null) {
					node.left = inserted_node;
					continue_ = false;
				} else {
					node = node.left;
				}
			} else if(node.key.unsigned > key) {
				if (node.right is null) {
					node.right = inserted_node;
					continue_ = false;
				} else {
					node = node.right;
				}
			} else {
				// the key already existed.
				// we have an AA implementation, so we do not care about duplicates,
				// we simply replace the old value with the new one
				node.value = inserted_node.value;
				// TODO: free inserted_node
				// Well not actually a todo, but calling some kind of freeDg would
				// be useful if you want to use the runtime without a GC

				return; // no checks needed, we only replaced a value
			}
		}

		inserted_node.parent = node;
	}

	rbt.length++;
	vrt_aa_insert_case1(rbt, inserted_node);
	//assert(vrt_aa_validate(rbt));
}


// same as vrt_aa_insert_primitive, only different comparison
extern(C) void vrt_aa_insert_array(void* rbtv, void[] key, void* value)
{
	RedBlackTree* rbt = cast(RedBlackTree*)rbtv;
	TreeNode* inserted_node = new TreeNode;
	inserted_node.key.array = key;
	inserted_node.red = true; // we have to check the rules afterwards and fix the tree!

	if (rbt.isValuePtr) {
		// allocate more memory for value
		void* mem = object.allocDg(rbt.value, 1);
		object.__llvm_memcpy(mem, value, rbt.value.size, 0, false);
		inserted_node.value.ptr = mem;
	} else {
		object.__llvm_memcpy(cast(void*)&(inserted_node.value), value, rbt.value.size, 0, false);
	}

	if (rbt.root is null) {
		rbt.root = inserted_node;
	} else {
		TreeNode* node = rbt.root;

		bool continue_ = true;
		while (continue_) {
			int comparison;
			if (node.key.array.length < key.length) {
				comparison = 1; // key.length is longer
			} else if (node.key.array.length > key.length) {
				comparison = -1; // key.length is shorter
			} else {
				comparison = object.vrt_memcmp(node.key.array.ptr, key.ptr, key.length);
			}

			if (comparison < 0) {
				if (node.left is null) {
					node.left = inserted_node;
					continue_ = false;
				} else {
					node = node.left;
				}
			} else if(comparison > 0) {
				if (node.right is null) {
					node.right = inserted_node;
					continue_ = false;
				} else {
					node = node.right;
				}
			} else {
				node.value = inserted_node.value;
				return;
			}
		}

		inserted_node.parent = node;
	}

	rbt.length++;
	vrt_aa_insert_case1(rbt, inserted_node);
	//assert(vrt_aa_validate(rbt));
}




private void vrt_aa_insert_case1(RedBlackTree* rbt, TreeNode* node)
{
	// Case 1: the new node is now the root node.
	// Simply color it black. The number of black nodes in each tree
	// will stay the same, since it is the root node.
	if (node.parent is null) { // root node found
		node.red = false;
	} else {
		// ok, it is not the root node, check case 2
		vrt_aa_insert_case2(rbt, node);
	}
}

private void vrt_aa_insert_case2(RedBlackTree* rbt, TreeNode* node)
{
	// Case 2: the new node has a black parent, if so everything is still fine
	if (node.parent.red) {
		// it is red!
		vrt_aa_insert_case3(rbt, node);
	}
}

private void vrt_aa_insert_case3(RedBlackTree* rbt, TreeNode* node)
{
	// Case 3: it's getting complicated,
	// Uncle node is red. So recolor parent and uncle black
	// (we have a red child), but now the grandparent
	// might violate the rules -> recursivly invoke the procedure from the start:
	// vrt_aa_insert_case1
	TreeNode* uncle = vrt_aa_get_sibling(node.parent);
	if (uncle !is null && uncle.red) { // uncle color
		node.parent.red = false;
		uncle.red = false;
		// assert(node.parent.parent !is null);
		// node.parent.parent should always be valid, otherwise the uncle color-check
		// should have been false
		node.parent.parent.red = true;
		vrt_aa_insert_case1(rbt, node.parent.parent);
	} else {
		// continue with case 4
		vrt_aa_insert_case4(rbt, node);
	}
}

private void vrt_aa_insert_case4(RedBlackTree* rbt, TreeNode* node)
{
	// Case 4: Fun!
	// * The new node is the right child of the parent, and the parent is the
	//   left child of the grandparent -> rotate left around parent
	// * The new node is the left child of the parent, and the parent is the
	//   right child of the grandparent -> rotate right around the parent
	// Both don't fix the tree, but make it fixable in step/case 5
	if (node is node.parent.right &&
	    node.parent is node.parent.parent.left) {
		vrt_aa_rotate_left(rbt, node.parent);
		node = node.left;
	} else if(node is node.parent.left &&
	          node.parent is node.parent.parent.right) {
		vrt_aa_rotate_right(rbt, node.parent);
		node = node.right;
	}

	vrt_aa_insert_case5(rbt, node);
}

private void vrt_aa_insert_case5(RedBlackTree* rbt, TreeNode* node)
{
	// Case 5: Case 4 fixed!
	// * The new node is the left child of the parent, and the parent is the
	//   left child of the grandparent -> rotate right around the grandparent
	// * The new node is the right child of the parent and the parent is the
	//   right child of the grandparent -> rotate left around the grandparent
	// Done! Our tree is valid again, hopefully!

	node.parent.red = false;
	node.parent.parent.red = true;
	if (node is node.parent.left &&
	    node.parent is node.parent.parent.left) {
		vrt_aa_rotate_right(rbt, node.parent.parent);
	} else if(node is node.parent.right &&
	          node.parent is node.parent.parent.right) {
		vrt_aa_rotate_left(rbt, node.parent.parent);
	} else {
		// should never happen...
		// error!
		// assert(false);
	}
}

extern(C) bool vrt_aa_delete_primitive(void* rbtv, ulong key)
{
	RedBlackTree* rbt = cast(RedBlackTree*) rbtv;
	TreeNode* child;
	TreeNode* node = vrt_aa_lookup_node_primitive(cast(void*)rbt, key);

	if (node is null) {
		// Key did not exist
		return false;
	}

	if (rbt.length == 0) {
		throw new Exception("AA size tracking failure");
	}
	rbt.length--;
    
	// deleting the node is basically the same as you would delete 
	// a node from a binary search tree
    
	// the node has two children!
	if (node.left !is null && node.right !is null) {
		TreeNode* pred = vrt_aa_iterate_right(node.left);
		node.key = pred.key;
		node.value = pred.value;
		node = pred;
	}
    
	// now the node only has one child left the other is null
	//child = node.right is null ? node.left : node.right;
	if (node.right is null) {
		child = node.left;
	} else {
		child = node.right;
	}

	if (!node.red) {
		// the node is black
		node.red = vrt_aa_node_is_red(child);
		vrt_aa_delete_case1(rbt, node);
	}

	vrt_aa_replace_node(rbt, node, child);
	if (node.parent is null && child !is null) {
		child.red = false;
	}
    
	return true;
}

// same as above for arrays
extern(C) bool vrt_aa_delete_array(void* rbtv, void[] key)
{
	RedBlackTree* rbt = cast(RedBlackTree*)rbtv;
	TreeNode* child;
	TreeNode* node = vrt_aa_lookup_node_array(rbtv, key);

	if (node is null) {
		return false;
	}
	if (node.left !is null && node.right !is null) {
		TreeNode* pred = vrt_aa_iterate_right(node.left);
		node.key = pred.key;
		node.value = pred.value;
		node = pred;
	}
	if (node.right is null) {
		child = node.left;
	} else {
		child = node.right;
	}
	if (!node.red) {
		node.red = vrt_aa_node_is_red(child);
		vrt_aa_delete_case1(rbt, node);
	}
	vrt_aa_replace_node(rbt, node, child);
	if (node.parent is null && child !is null) {
		child.red = false;
	}
	return true;
}

// aa.keys
extern (C) void[] vrt_aa_get_keys(void* rbtv)
{
	if (rbtv is null) {
		return [];
	}
	auto rbt = cast(RedBlackTree*) rbtv;
	auto arr = object.allocDg(rbt.key, rbt.length)[0 .. rbt.length * rbt.key.size];
	size_t currentIndex;
	vrt_aa_walk(rbt, rbt.root, true, rbt.key.size, ref arr, ref currentIndex);
	return arr;
}

// aa.values
extern (C) void[] vrt_aa_get_values(void* rbtv)
{
	if (rbtv is null) {
		return [];
	}
	auto rbt = cast(RedBlackTree*) rbtv;
	auto arr = object.allocDg(rbt.value, rbt.length)[0 .. rbt.length * rbt.value.size];
	size_t currentIndex;
	vrt_aa_walk(rbt, rbt.root, false, rbt.value.size, ref arr, ref currentIndex);
	return arr;
}

// aa.rehash
extern (C) void vrt_aa_rehash(void* rbtv)
{
}

private void vrt_aa_walk(RedBlackTree* rbt, TreeNode* node, bool getKey, size_t argSize, ref void[] arr, ref size_t currentIndex)
{
	if (node !is null) {
		vrt_aa_walk(rbt, node.left, getKey, argSize, ref arr, ref currentIndex);
		auto tn = getKey ? node.key : node.value;

		if (argSize > typeid(TreeStore).size) {
			object.__llvm_memcpy(&arr[currentIndex], tn.ptr, argSize, 0, false);
		} else {
			object.__llvm_memcpy(&arr[currentIndex], cast(void*)&tn, argSize, 0, false);
		}
		currentIndex += argSize;
		vrt_aa_walk(rbt, node.right, getKey, argSize, ref arr, ref currentIndex);
	}
}

private void vrt_aa_delete_case1(RedBlackTree* rbt, TreeNode* node)
{
	// If the root node was replaced (parent is null) no 
	// propierties were violated
	if (node.parent !is null) {
		vrt_aa_delete_case2(rbt, node);
	}
}

private void vrt_aa_delete_case2(RedBlackTree* rbt, TreeNode* node)
{
	// The node has a red sibling, so we switch the colors of the parent
	// and the sibling. Afterwards we rotate so that the sibling
	// becomes the parent. This does not fix the tree.
	TreeNode* sibling = vrt_aa_get_sibling(node);
	if (sibling !is null && sibling.red) {
		node.parent.red = true;
		sibling.red = false;
		if (node is node.parent.left) {
			// we are the left node
			vrt_aa_rotate_left(rbt, node.parent);
		} else {
			// and here we are the right node
			vrt_aa_rotate_right(rbt, node.parent);
		}
	}
    
	vrt_aa_delete_case3(rbt, node);
}

private void vrt_aa_delete_case3(RedBlackTree* rbt, TreeNode* node)
{
	// If the parent, sibling and sibling children are black,
	// we paint the sibling red, we have to run this recursivly up
	// until we reach the tree node
	TreeNode* sibling = vrt_aa_get_sibling(node);
	if (!node.parent.red &&
	    !vrt_aa_node_is_red(sibling) &&
	    !vrt_aa_node_is_red(sibling.left) &&
	    !vrt_aa_node_is_red(sibling.right)) { // everyone is black
		sibling.red = true;
		vrt_aa_delete_case1(rbt, node.parent);
	} else {
		vrt_aa_delete_case4(rbt, node);
	}
}

private void vrt_aa_delete_case4(RedBlackTree* rbt, TreeNode* node)
{
	// If the parent is red, but sibling and sibling children are black,
	// we paint the sibling red and the parent black
	TreeNode* sibling = vrt_aa_get_sibling(node);
	if (node.parent.red &&
	    !vrt_aa_node_is_red(sibling) &&
	    !vrt_aa_node_is_red(sibling.left) &&
	    !vrt_aa_node_is_red(sibling.right)) {
		sibling.red = true;
		node.parent.red = false;
	} else {
		vrt_aa_delete_case5(rbt, node);
	}
}

private void vrt_aa_delete_case5(RedBlackTree* rbt, TreeNode* node)
{
	TreeNode* sibling = vrt_aa_get_sibling(node);
	if (node is node.parent.left &&
	    !vrt_aa_node_is_red(sibling) &&
	    vrt_aa_node_is_red(sibling.left) &&
	    !vrt_aa_node_is_red(sibling.right)) {
		sibling.red = true;
		sibling.left.red = false;
		vrt_aa_rotate_right(rbt, sibling);
	} else if(node is node.parent.right &&
	    !vrt_aa_node_is_red(sibling) &&
	    !vrt_aa_node_is_red(sibling.left) &&
	    vrt_aa_node_is_red(sibling.right)) {
		sibling.red = true;
		sibling.right.red = false;
		vrt_aa_rotate_left(rbt, sibling);
	}
	
	vrt_aa_delete_case6(rbt, node);
}

private void vrt_aa_delete_case6(RedBlackTree* rbt, TreeNode* node)
{
	TreeNode* sibling = vrt_aa_get_sibling(node);
	sibling.red = node.parent.red;
	node.parent.red = false;
	if (node is node.parent.left) {
		sibling.right.red = false;
		vrt_aa_rotate_left(rbt, node.parent);
	} else {
		sibling.left.red = false;
		vrt_aa_rotate_right(rbt, node.parent);
	}
}

private bool vrt_aa_node_is_red(TreeNode* node)
{
	return node is null ? false : node.red;
}

private TreeNode* vrt_aa_get_sibling(TreeNode* node)
{
	if (node is node.parent.left) {
		return node.parent.right;
	} else {
		return node.parent.left;
	}
}

private TreeNode* vrt_aa_iterate_right(TreeNode* node)
{
    while (node.right !is null) {
        node = node.right;
    }
    
    return node;
}

bool vrt_aa_validate(void* rbtv)
{
	RedBlackTree* rbt = cast(RedBlackTree*)rbtv;
	if (rbt.root is null) {
		return true;
	}

	// Rule 1: A node is either red or black
	// We use a boolean to indicate color -> always true

	// Rule 2: Root node is black!
	if (rbt.root.red) {
		return false;
	}

	// Rule 3: All leaves are black (same color as root)
	// Since our NIL (null) is by definition black, all leaves are black

	// Rule 4: Both children of every red node are black
	if (!vrt_aa_validate_rule4(rbt.root)) {
		return false;
	}

	// Rule 5: Every simple path from a given node to any of its
	// descendant leaves contains the same number of black nodes.
	if (!vrt_aa_validate_rule5(rbt.root)) {
		return false;
	}

	return true;
}

private bool vrt_aa_validate_rule4(TreeNode* node)
{
	// we reached a leaf: nil
	if (node is null) {
		return true;
	}
    
	if (node.red) { // red
		// children have to be black, if one of them is red (true), return false
		if (vrt_aa_node_is_red(node.left) ||
		    vrt_aa_node_is_red(node.right) ||
		    vrt_aa_node_is_red(node.parent)) {
			return false;
		}
	}

	return vrt_aa_validate_rule4(node.left) && vrt_aa_validate_rule4(node.right);
}

private bool vrt_aa_validate_rule5(TreeNode* node)
{
	// How does this work?
	// We traverse the RBT, when we reach a leaf and "black_nodes" is -1, then
	// we set the current number of previously visited black nodes in "black_nodes".
	// But if we reach a leaf and "black_nodes" is not -1, then we compare the number
	// of previously visited black nodes with "black_nodes", if they equal, everything
	// is fine, if not, our RBT is not valid and we return false, which will stop the
	// traversal and return false.
	int black_nodes = -1;

	return vrt_aa_validate_rule5_impl(node, 0, &black_nodes);
}

private bool vrt_aa_validate_rule5_impl(TreeNode* node, int previouse_black_nodes, int* black_nodes)
{
	if (node !is null && !node.red) { // node is black
		previouse_black_nodes += 1;
	}

	if (node is null) { // nil = leaf reched
		if(*black_nodes == -1) { // first time we reached a leaf
			*black_nodes = previouse_black_nodes;
		} else if(previouse_black_nodes != *black_nodes) {
			return false;
		}

		return true;
	}

	return vrt_aa_validate_rule5_impl(node.left, previouse_black_nodes, black_nodes) &&
		   vrt_aa_validate_rule5_impl(node.right, previouse_black_nodes, black_nodes);
}
