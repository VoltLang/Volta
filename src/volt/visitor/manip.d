// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.manip;

import ir = volt.ir.ir;


/**
 * Return true to indicate that the given node @n should be kept
 * and that the node list @list be ignored, return false to indicate
 * that @n replaced with @list.
 */
alias ReplaceDg = bool delegate(ir.Node n, out ir.Node[] list);

/**
 * Loops over all the given nodes and calls @replaceDg for each,
 * if it returns true @replaceDg will insert back the given node,
 * or replace it with the out variable list if it returns false.
 *
 * Returns the manipulated list.
 */
ir.Node[] manipNodes(ir.Node[] nodes, ReplaceDg replaceDg)
{
	ir.Node[] ret;
	size_t size;

	void ensureSpaceFor(size_t e) {
		auto newSize = size + e;

		while(ret.length < newSize) {
			ret.length = ret.length * 2 + 3;
		}
	}

	foreach(node; nodes) {
		ir.Node[] list;
		auto replace = replaceDg(node, list);

		if (!replace) {
			ensureSpaceFor(1);
			ret[size++] = node;
		} else if (list.length > 0) {
			ensureSpaceFor(list.length);
			ret[size .. size + list.length] = list[0 .. $];
			size += list.length;
		}
	}

	return ret[0 .. size];
}
