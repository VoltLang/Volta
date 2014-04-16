// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.attribremoval;

import std.stdio : writefln;

import volt.ir.util;

import ir = volt.ir.ir;
import volt.errors;
import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.manip;
import volt.semantic.classify;


/**
 * A pass that turns Attributes nodes into fields on to
 * Functions, Classes and the like.
 *
 * @ingroup passes passLang
 */
class AttribRemoval : NullVisitor, Pass
{
public:
	LanguagePass lp;

protected:
	ir.Attribute[] mStack;
	Context[] mCtx;

	/**
	 * Helper class.
	 */
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
	this(LanguagePass lp)
	{
		this.lp = lp;
	}

	/*
	 * Things that do stuff.
	 */
	override Status enter(ir.Module m)
	{
		mCtx = [new Context(m)];
		return Continue;
	}

	override Status enter(ir.TopLevelBlock tlb)
	{
		// Filter out any Attributes.
		tlb.nodes = manipNodes(tlb.nodes, &nodeManipDg);
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
		ctxPush(fn);
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
		ctxPush(s);
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		applyAttributes(u, ctxTop.stack);
		applyAttributes(u, mStack);
		ctxPush(u);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		applyAttributes(c, ctxTop.stack);
		applyAttributes(c, mStack);
		ctxPush(c);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		applyAttributes(i, ctxTop.stack);
		applyAttributes(i, mStack);
		ctxPush(i);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		applyAttributes(e, ctxTop.stack);
		applyAttributes(e, mStack);
		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		applyAttributes(a, ctxTop.stack);
		applyAttributes(a, mStack);
		return Continue;
	}

	override Status leave(ir.Function fn) { ctxPop(fn); return Continue; }
	override Status leave(ir.Struct s) { ctxPop(s); return Continue; }
	override Status leave(ir.Union u) { ctxPop(u); return Continue; }
	override Status leave(ir.Class c) { ctxPop(c); return Continue; }
	override Status leave(ir._Interface i) { ctxPop(i); return Continue; }

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
			case Static:
				i.isStatic = true;
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
				if (lp.settings.platform == Platform.MinGW) {
					fn.type.linkage = ir.Linkage.Windows;
				} else {
					fn.type.linkage = ir.Linkage.C;
				}
				break;
			case LoadDynamic:
				fn.loadDynamic = true;
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
			case Scope:
				fn.type.isScope = true;
				break;
			case Property:
				if (fn.type.params.length == 0) {
					if (isVoid(fn.type.ret)) {
						throw makeInvalidType(fn, buildVoid(fn.location));
					}
				} else {
					if (fn.type.params.length != 1) {
						throw makeWrongNumberOfArguments(fn, fn.type.params.length, isVoid(fn.type.ret) ? 0 : 1);
					}
				}
				fn.type.isProperty = true;
				break;
			case UserAttribute:
				fn.userAttrs ~= attr;
				break;
			case Override:
				fn.isMarkedOverride = true;
				break;
			case Abstract:
				fn.isAbstract = true;
				break;
			case Local, Global:
				with (ir.Function.Kind) {
				if (fn.kind == Constructor) {
					if (attr.kind == ir.Attribute.Kind.Local) {
						throw panic(attr.location, "local constructors are unimplemented.");
					}
					fn.kind = attr.kind == ir.Attribute.Kind.Local ? LocalConstructor : GlobalConstructor;
				} else if (fn.kind == Destructor) {
					if (attr.kind == ir.Attribute.Kind.Local) {
						throw panic(attr.location, "local destructors are unimplemented.");
					}
					fn.kind = attr.kind == ir.Attribute.Kind.Local ? LocalDestructor : GlobalDestructor;
				} else {
					fn.kind = ir.Function.Kind.Function;
				}
				} // with
				break;
			case MangledName:
				assert(attr.arguments.length == 1);
				auto constant = cast(ir.Constant) attr.arguments[0];
				if (constant is null || !isString(constant.type) || constant._string.length <= 2) {
					throw makeExpected(attr, "non empty string literal argument to MangledName.");
				}
				assert(constant._string[0] == '\"');
				assert(constant._string[$-1] == '\"');
				fn.mangledName = constant._string[1..$-1];
				break;
			case Static:
				fn.kind = ir.Function.Kind.Function;
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
			case LinkageVolt:
				d.linkage = ir.Linkage.Volt;
				break;
			case LinkageC:
				d.linkage = ir.Linkage.C;
				break;
			case LinkageCPlusPlus:
				d.linkage = ir.Linkage.CPlusPlus;
				break;
			case LinkageWindows:
				d.linkage = ir.Linkage.Windows;
				break;
			case LinkagePascal:
				d.linkage = ir.Linkage.Pascal;
				break;
			case LinkageSystem:
				if (lp.settings.platform == Platform.MinGW) {
					d.linkage = ir.Linkage.Windows;
				} else {
					d.linkage = ir.Linkage.C;
				}
				break;
			case Extern:
				d.isExtern = true;
				break;
			case UserAttribute:
				d.userAttrs ~= attr;
				break;
			default:
				// Warn?
			}
		}
	}

	/**
	 * Loops over all attributes and applies them.
	 */
	void applyAttributes(ir.Aggregate s, ir.Attribute[] attrs)
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
			case UserAttribute:
				s.userAttrs ~= attr;
				break;
			case Abstract:
				auto c = cast(ir.Class) s;
				if (c is null) {
					throw makeBadAbstract(s, attr);
				}
				c.isAbstract = true;
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
			case UserAttribute:
				i.userAttrs ~= attr;
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

	Context ctxTop()
	{
		return mCtx[$-1];
	}

	void ctxPush(ir.Node node, bool inherit = false)
	{
		auto mCtx = new Context(node);

		mCtx.node = node;
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
		while (mStack.length > 0 && attrTop().members is null) {
			attrPop(attrTop());
		}

		if (node !is ctxTop.node) {
			throw panic(node, "invalid attribute stack layout");
		}
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

		if (attr.members is null) {
			return null;
		}

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
		switch (node.nodeType) with (ir.NodeType) {
		case Attribute:
			auto attr = cast(ir.Attribute)node;
			ret = attrManip(attr);
			return true;
		case Function:
			auto fn = cast(ir.Function)node;
			accept(fn, this);
			if (!fn.loadDynamic) {
				return false;
			}
			if (fn._body !is null) {
				throw makeCannotLoadDynamic(node, fn);
			}
			auto var = new ir.Variable();
			var.location = fn.location;
			var.name = fn.name;
			var.type = fn.type;
			var.access = fn.access;
			var.storage = ir.Variable.Storage.Global;
			ret = [cast(ir.Node)var];
			return true;
		default:
			accept(node, this);
			return false;
		}
	}


public:
	/*
	 * Pass.
	 */
	void transform(ir.Module m)
	{
		assert(mStack.length == 0);
		assert(mCtx.length == 0);
		accept(m, this);
		mStack = [];
		mCtx = [];
	}

	void close()
	{
	}
}
