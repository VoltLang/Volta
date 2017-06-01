// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.util.worktracker;

import watt.text.sink : StringSink;

import ir = volt.ir.ir;

import volt.errors;


class Work
{
public:
	enum Action
	{
		Resolve   = 0,
		Actualize = 1,
	}

	//! The node to check for rentry.
	ir.Node node;
	//! Action being taken.
	Action action;

private:
	WorkTracker mTracker;

public:
	this(WorkTracker wt, ir.Node n, Action action)
	{
		this.node = n;
		this.action = action;
		this.mTracker = wt;
	}

	void done()
	{
		mTracker.remove(this);
	}

	@property string description()
	{
		StringSink sink;
		sink.sink(node.loc.toString());
		sink.sink(" ");
		if (action == Action.Resolve) {
			sink.sink("resolving");
		} else {
			sink.sink("actualising");
		}
		sink.sink(" ");
		sink.sink(ir.nodeToString(node));
		sink.sink(" ");
		sink.sink(ir.getNodeAddressString(node));
		return sink.toString();
	}

protected:
	@property ulong key()
	{
		assert(!((3UL << 62) & node.uniqueId));
		return cast(ulong)action << 62 | node.uniqueId;
	}
}

class WorkTracker
{
private:
	Work[] mStack;
	Work[ulong] mMap;

public:
	Work add(ir.Node n, Work.Action action)
	{
		auto w = new Work(this, n, action);
		auto key = w.key;

		auto ret = key in mMap;
		if (ret is null) {
			mStack ~= w;
			mMap[key] = w;
			return w;
		}

		StringSink str;
		str.sink("circular dependency detected");
		foreach (s; mStack) {
			str.sink("\n");
			str.sink(s.description);
		}
		throw makeError(w.node.loc, str.toString());
	}

	void remove(Work w)
	{
		mMap.remove(w.key);
		foreach (i, elm; mStack) {
			if (elm !is w)
				continue;

			mStack = mStack[0 .. i] ~ mStack[i+1 .. $];
			return;
		}

		assert(false);
	}
}
