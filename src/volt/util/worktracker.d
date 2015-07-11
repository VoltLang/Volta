// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.util.worktracker;

import ir = volt.ir.ir;

import volt.errors;


class Work
{
public:
	/// The node to check for rentry.
	ir.Node node;
	/// Action being taken.
	string action;

private:
	WorkTracker mTracker;

public:
	this(WorkTracker wt, ir.Node n, string action)
	{
		this.node = n;
		this.action = action;
		this.mTracker = wt;
	}

	void done()
	{
		mTracker.remove(this);
	}

protected:
	override nothrow @trusted size_t toHash()
	{
		return *cast(size_t*)&node;
	}

	override int opCmp(Object rhs)
	{
		if (this is rhs)
			return true;

		auto rw = cast(Work)rhs;
		if (rw is null)
			return -1;

		if (node !is rw.node)
			return -1;
		if (action != rw.action)
			return 1;
		return 0;
	}

	override bool opEquals(Object rhs)
	{
		auto rh = cast(Work) rhs;
		if (rh is null) {
			return false;
		}
		return rh.node is this.node && rh.action == this.action;
	}
}

class WorkTracker
{
private:
	Work[] mStack;
	Work[Work] mMap;

	struct Key
	{
		size_t v;
		string action;
	}

public:
	Work add(ir.Node n, string action)
	{
		auto w = new Work(this, n, action);

		auto ret = w in mMap;
		if (ret is null) {
			mMap[w] = w;
			mStack ~= w;
			return w;
		}

		auto str = "circular dependancy detected";
		foreach_reverse(s; mStack) {
			str ~= "\n" ~ s.node.location.toString ~ "   " ~ w.action;
		}
		throw makeError(w.node.location, str);
	}

	void remove(Work w)
	{
		mMap.remove(w);
		foreach (i, elm; mStack) {
			if (elm !is w)
				continue;

			mStack = mStack[0 .. i] ~ mStack[i+1 .. $];
			return;
		}

		assert(false);
	}
}
