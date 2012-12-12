// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.attribremoval;

import std.stdio : writefln;

import ir = volt.ir.ir;
import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.manip;


/**
 * A pass that turns Attributes nodes into fields on to
 * Functions, Classes and the like.
 */
class AttribRemoval : NullVisitor, Pass
{
protected:
	ir.Attribute[] mStack;
	Context[] mCtx;

	static class Context
	{
		this(ir.Node node)
		{
			this.node = node;
		}

		ir.Node node;
		ir.Attribute[] stack;
		ir.Attribute[] oldStack;
	}


public:
	/*
	 * Things that do stuff.
	 */
	override Status enter(ir.Module m)
	{
		mCtx = [new Context(m)];

		// Filter out any Attributes.
		m.children.nodes = manipNodes(m.children.nodes, &nodeManipDg);

		return ContinueParent;
	}

	override Status enter(ir.Import i)
	{
		applyAttributes(i, ctxTop.stack);
		applyAttributes(i, mStack);

		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		applyAttributes(fn, ctxTop.stack);
		applyAttributes(fn, mStack);

		return Continue;
	}

	override Status enter(ir.Variable d)
	{
		applyAttributes(d, ctxTop.stack);
		applyAttributes(d, mStack);

		return Continue;
	}

	override Status enter(ir.Struct s)
	{
		applyAttributes(s, ctxTop.stack);
		applyAttributes(s, mStack);

		return Continue;
	}

	override Status enter(ir.Class c)
	{
		applyAttributes(c, ctxTop.stack);
		applyAttributes(c, mStack);

		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		applyAttributes(i, ctxTop.stack);
		applyAttributes(i, mStack);

		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		applyAttributes(e, ctxTop.stack);
		applyAttributes(e, mStack);

		return Continue;
	}

	override Status visit(ir.Alias a)
	{
		applyAttributes(a, ctxTop.stack);
		applyAttributes(a, mStack);

		return Continue;
	}

	override Status leave(ir.Module m) { assert(false); }
	override Status leave(ir.Import i) { return Continue; }
	override Status leave(ir.Function fn) { return Continue; }
	override Status leave(ir.Variable d) { return Continue; }
	override Status leave(ir.Class c) { return Continue; }
	override Status leave(ir._Interface i) { return Continue; }
	override Status leave(ir.Struct s) { return Continue; }
	override Status leave(ir.Enum e) { return Continue; }

	override Status enter(ir.Attribute attr) { assert(false); }
	override Status leave(ir.Attribute attr) { assert(false); }

protected:
	/*
	 * Apply functions.
	 */

	/**
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Import i, ir.Attribute[] attrs)
	{
		foreach(attr; attrs) {
			switch(attr.kind) with (ir.Attribute.Kind) {
			case Public:
				i.access = ir.Access.Public;
				break;
			case Private:
				i.access = ir.Access.Private;
				break;
			case Package:
				i.access = ir.Access.Package;
				break;
			case Protected:
				i.access = ir.Access.Protected;
				break;
			default:
				// Warn?
			}
		}
	}

	/**
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Function fn, ir.Attribute[] attrs)
	{
		foreach(attr; attrs) {
			switch(attr.kind) with (ir.Attribute.Kind) {
			case LinkageVolt:
				fn.type.linkage = ir.Linkage.Volt;
				break;
			case LinkageC:
				fn.type.linkage = ir.Linkage.C;
				break;
			case LinkageCPlusPlus:
				fn.type.linkage = ir.Linkage.CPlusPlus;
				break;
			case LinkageWindows:
				fn.type.linkage = ir.Linkage.Windows;
				break;
			case LinkagePascal:
				fn.type.linkage = ir.Linkage.Pascal;
				break;
			case LinkageSystem:
				fn.type.linkage = ir.Linkage.System;
				break;
			case Public:
				fn.access = ir.Access.Public;
				break;
			case Private:
				fn.access = ir.Access.Private;
				break;
			case Package:
				fn.access = ir.Access.Package;
				break;
			case Protected:
				fn.access = ir.Access.Protected;
				break;
			default:
				// Warn?
			}
		}
	}

	/**
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Variable d, ir.Attribute[] attrs)
	{
		foreach(attr; attrs) {
			switch(attr.kind) with (ir.Attribute.Kind) {
			case Public:
				d.access = ir.Access.Public;
				break;
			case Private:
				d.access = ir.Access.Private;
				break;
			case Package:
				d.access = ir.Access.Package;
				break;
			case Protected:
				d.access = ir.Access.Protected;
				break;
			case Global:
				d.storage = ir.Variable.Storage.Global;
				break;
			case Local:
				d.storage = ir.Variable.Storage.Local;
				break;
			default:
				// Warn?
			}
		}
	}

	/**
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Struct s, ir.Attribute[] attrs)
	{
		foreach(attr; attrs) {
			switch(attr.kind) with (ir.Attribute.Kind) {
			case Public:
				s.access = ir.Access.Public;
				break;
			case Private:
				s.access = ir.Access.Private;
				break;
			case Package:
				s.access = ir.Access.Package;
				break;
			case Protected:
				s.access = ir.Access.Protected;
				break;
			default:
				// Warn?
			}
		}
	}

	/**
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Class c, ir.Attribute[] attrs)
	{
		foreach(attr; attrs) {
			switch(attr.kind) with (ir.Attribute.Kind) {
			case Public:
				c.access = ir.Access.Public;
				break;
			case Private:
				c.access = ir.Access.Private;
				break;
			case Package:
				c.access = ir.Access.Package;
				break;
			case Protected:
				c.access = ir.Access.Protected;
				break;
			default:
				// Warn?
			}
		}
	}

	/**
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir._Interface i, ir.Attribute[] attrs)
	{
		foreach(attr; attrs) {
			switch(attr.kind) with (ir.Attribute.Kind) {
			case Public:
				i.access = ir.Access.Public;
				break;
			case Private:
				i.access = ir.Access.Private;
				break;
			case Package:
				i.access = ir.Access.Package;
				break;
			case Protected:
				i.access = ir.Access.Protected;
				break;
			default:
				// Warn?
			}
		}
	}

	/**
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Enum e, ir.Attribute[] attrs)
	{
		foreach(attr; attrs) {
			switch(attr.kind) with (ir.Attribute.Kind) {
			case Public:
				e.access = ir.Access.Public;
				break;
			case Private:
				e.access = ir.Access.Private;
				break;
			case Package:
				e.access = ir.Access.Package;
				break;
			case Protected:
				e.access = ir.Access.Protected;
				break;
			default:
				// Warn?
			}
		}
	}

	/**
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Alias a, ir.Attribute[] attrs)
	{
		foreach(attr; attrs) {
			switch(attr.kind) with (ir.Attribute.Kind) {
			case Public:
				a.access = ir.Access.Public;
				break;
			case Private:
				a.access = ir.Access.Private;
				break;
			case Package:
				a.access = ir.Access.Package;
				break;
			case Protected:
				a.access = ir.Access.Protected;
				break;
			default:
				// Warn?
			}
		}
	}

	ir.Node accept(ir.Node node)
	{
		.accept(node, this);
		return node;
	}

	Context ctxTop()
	{
		return mCtx[$-1];
	}

	void ctxPush(ir.Node node, bool inherit = false)
	{
		auto mCtx = new Context(node);

		mCtx.oldStack = this.mStack;
		if (inherit)
			mCtx.stack = this.mStack ~ ctxTop.stack;
		else
			mCtx.stack = this.mStack;

		this.mCtx ~= mCtx;
		this.mStack = null; // Stack has been saved.
	}

	void ctxPop(ir.Node node)
	{
		assert(node is ctxTop.node);
		this.mStack = ctxTop.oldStack;
		this.mCtx = mCtx[0 .. $-1];
	}

	ir.Attribute attrTop()
	{
		return mStack[$-1];
	}

	void attrPush(ir.Attribute attr)
	{
		mStack ~= attr;
	}

	void attrPop(ir.Attribute attr)
	{
		assert(attrTop is attr);
		mStack = mStack[0 .. $-1];
	}

	void attrPushDown()
	{
		mCtx[$-1].stack ~= mStack;
	}

	ir.Node[] attrManip(ir.Attribute attr)
	{
		attrPush(attr);

		scope(exit) {
			if (attr.members.nodes.length > 0)
		    	ctxPop(attr);
			attrPop(attr);
		}

		if (attr.members.nodes.length > 0) {
			ctxPush(attr, true);
			return manipNodes(attr.members.nodes, &nodeManipDg);
		} else {
			return null;
		}
	}

	bool nodeManipDg(ir.Node node, out ir.Node[] ret)
	{
		auto attr = cast(ir.Attribute)node;
		if (attr !is null) {
			ret = attrManip(attr);
			return true;
		}

		.accept(node, this);
		return false;
	}


public:
	/*
	 * Pass.
	 */
	void transform(ir.Module m)
	{
		.accept(m, this);
	}

	void close()
	{
	}
}
